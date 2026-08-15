import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_model.dart';

// Handles everything to do with a user's wallet balance and the manual
// deposit/withdrawal flow. No real money ever moves through this app -
// money moves by hand via mobile money, and this service only keeps the
// numbers in sync with what an admin has manually confirmed.
//
// IMPORTANT: every method that changes a balance uses Firestore's
// runTransaction so a balance update and its related transaction record
// can never happen independently. That was the root cause of an earlier
// bug where bets were placed without the wallet being deducted - two
// separate writes, one of which silently failed.
class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _transactionsCollection = 'transactions';

  // Withdrawal charge - admin keeps 12%, user receives 88% of what they asked for
  static const double withdrawalChargeRate = 0.12;
  static const double minimumWithdrawal = 5000;

  // Where users send money for deposits - shown on the Deposit screen
  static const String adminMomoNumber = '0768658988';
  static const String adminMomoName = 'Drake Wanswa';

  // A short code the user quotes when sending money so the admin can match
  // their payment to the right transaction. e.g. "JCS-4821-DRK"
  static String generateReference(String userName) {
    final random = Random();
    final number = 1000 + random.nextInt(9000);
    final clean = userName.replaceAll(' ', '').toUpperCase();
    final nameCode = clean.length >= 3 ? clean.substring(0, 3) : clean;
    return 'JCS-$number-$nameCode';
  }

  // ---------------------------------------------------------------------
  // READING BALANCES
  // ---------------------------------------------------------------------

  // Live wallet balance for a user. Treats a missing field as 0 so this
  // works even for users who existed before the wallet feature was added.
  Stream<double> getWalletBalance(String userId) {
    return _firestore.collection(_usersCollection).doc(userId).snapshots().map(
      (doc) {
        if (!doc.exists) return 0.0;
        final data = doc.data() as Map<String, dynamic>;
        return (data['walletBalance'] ?? 0).toDouble();
      },
    );
  }

  // Live "money currently promised out but not yet sent" - shown to the
  // user so they understand why a pending withdrawal isn't spendable.
  Stream<double> getPendingWithdrawalAmount(String userId) {
    return _firestore.collection(_usersCollection).doc(userId).snapshots().map(
      (doc) {
        if (!doc.exists) return 0.0;
        final data = doc.data() as Map<String, dynamic>;
        return (data['pendingWithdrawal'] ?? 0).toDouble();
      },
    );
  }

  // ---------------------------------------------------------------------
  // TRANSACTION HISTORY
  // ---------------------------------------------------------------------

  // A user's own deposit/withdrawal history, newest first.
  // Fetches all of this user's transactions then sorts in Dart - same
  // approach match_service.dart uses to avoid needing composite indexes.
  Stream<List<WalletTransactionModel>> getMyTransactions(String userId) {
    return _firestore
        .collection(_transactionsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Admin - every deposit request still waiting for confirmation
  Stream<List<WalletTransactionModel>> getPendingDeposits() {
    return _firestore
        .collection(_transactionsCollection)
        .where('type', isEqualTo: TransactionType.deposit)
        .where('status', isEqualTo: TransactionStatus.pending)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // Admin - every withdrawal request still waiting to be paid out
  Stream<List<WalletTransactionModel>> getPendingWithdrawals() {
    return _firestore
        .collection(_transactionsCollection)
        .where('type', isEqualTo: TransactionType.withdrawal)
        .where('status', isEqualTo: TransactionStatus.pending)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // ---------------------------------------------------------------------
  // DEPOSITS
  // ---------------------------------------------------------------------

  // Step 1 of a deposit - user says "I've sent the money". This does NOT
  // touch the wallet balance yet. It only creates a pending record for
  // the admin to check against their own mobile money.
  Future<Map<String, dynamic>> requestDeposit({
    required String userId,
    required String userName,
    required double amount,
    String? momoNumber,
    String? reference,
  }) async {
    try {
      if (amount <= 0) {
        return {'success': false, 'message': 'Enter a valid amount'};
      }

      final txn = WalletTransactionModel(
        id: '',
        userId: userId,
        userName: userName,
        type: TransactionType.deposit,
        amount: amount,
        momoNumber: momoNumber,
        reference: reference,
        status: TransactionStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore.collection(_transactionsCollection).add(txn.toMap());

      return {
        'success': true,
        'message':
            'Deposit request submitted. The admin will confirm it once they receive your payment.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit deposit: $e'};
    }
  }

  // Step 2 of a deposit - admin has checked their own mobile money and
  // confirms it arrived. This is the ONLY place a deposit ever credits
  // the wallet, and it happens atomically with marking the request
  // confirmed so the two can never drift apart.
  Future<Map<String, dynamic>> confirmDeposit({
    required String transactionId,
    required String adminId,
  }) async {
    try {
      final txnRef =
          _firestore.collection(_transactionsCollection).doc(transactionId);

      await _firestore.runTransaction((transaction) async {
        final txnSnap = await transaction.get(txnRef);
        if (!txnSnap.exists) {
          throw Exception('Transaction not found');
        }
        final txnData = txnSnap.data() as Map<String, dynamic>;

        if (txnData['status'] != TransactionStatus.pending) {
          throw Exception('This deposit has already been actioned');
        }

        final String userId = txnData['userId'];
        final double amount = (txnData['amount'] ?? 0).toDouble();
        final userRef = _firestore.collection(_usersCollection).doc(userId);

        // Read the user doc too - all reads must happen before any writes
        // inside a Firestore transaction.
        await transaction.get(userRef);

        transaction.update(txnRef, {
          'status': TransactionStatus.confirmed,
          'confirmedAt': FieldValue.serverTimestamp(),
          'confirmedBy': adminId,
        });

        // SetOptions(merge: true) means this also works for a user doc
        // that has never had a walletBalance field before - it gets
        // created instead of throwing.
        transaction.set(
          userRef,
          {'walletBalance': FieldValue.increment(amount)},
          SetOptions(merge: true),
        );
      });

      return {
        'success': true,
        'message': 'Deposit confirmed and wallet topped up'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to confirm deposit: $e'};
    }
  }

  // Admin rejects a deposit (e.g. money never actually arrived)
  Future<Map<String, dynamic>> rejectDeposit({
    required String transactionId,
    required String adminId,
  }) async {
    try {
      await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .update({
        'status': TransactionStatus.rejected,
        'confirmedAt': FieldValue.serverTimestamp(),
        'confirmedBy': adminId,
      });
      return {'success': true, 'message': 'Deposit rejected'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to reject deposit: $e'};
    }
  }

  // ---------------------------------------------------------------------
  // WITHDRAWALS
  // ---------------------------------------------------------------------

  // Step 1 of a withdrawal - user requests a payout. The requested amount
  // is moved out of walletBalance into pendingWithdrawal IMMEDIATELY (in
  // the same transaction as creating the request) so the user can't spend
  // or double-withdraw money that's already promised out.
  Future<Map<String, dynamic>> requestWithdrawal({
    required String userId,
    required String userName,
    required double amount,
    String? momoNumber,
  }) async {
    try {
      if (amount < minimumWithdrawal) {
        return {
          'success': false,
          'message': 'Minimum withdrawal is UGX ${minimumWithdrawal.toInt()}'
        };
      }
      if (momoNumber == null || momoNumber.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Enter the mobile money number to receive your payout'
        };
      }

      final userRef = _firestore.collection(_usersCollection).doc(userId);
      final txnRef = _firestore.collection(_transactionsCollection).doc();
      final double netAmountToSend = amount * (1 - withdrawalChargeRate);

      await _firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final double currentBalance = userSnap.exists
            ? ((userSnap.data() as Map<String, dynamic>)['walletBalance'] ?? 0)
                .toDouble()
            : 0.0;

        if (currentBalance < amount) {
          throw Exception('Insufficient wallet balance');
        }

        transaction.set(
          userRef,
          {
            'walletBalance': FieldValue.increment(-amount),
            'pendingWithdrawal': FieldValue.increment(amount),
          },
          SetOptions(merge: true),
        );

        transaction.set(txnRef, {
          'userId': userId,
          'userName': userName,
          'type': TransactionType.withdrawal,
          'amount': amount,
          'netAmountToSend': netAmountToSend,
          'momoNumber': momoNumber,
          'reference': null,
          'status': TransactionStatus.pending,
          'createdAt': FieldValue.serverTimestamp(),
          'confirmedAt': null,
          'confirmedBy': null,
        });
      });

      return {
        'success': true,
        'message':
            'Withdrawal requested. You will receive UGX ${netAmountToSend.toInt()} after the 12% charge, once the admin sends it.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to request withdrawal: $e'};
    }
  }

  // Step 2 of a withdrawal - admin has manually sent the money from their
  // own phone and confirms it. The amount already left walletBalance at
  // request time, so this only clears it out of pendingWithdrawal.
  Future<Map<String, dynamic>> confirmWithdrawal({
    required String transactionId,
    required String adminId,
  }) async {
    try {
      final txnRef =
          _firestore.collection(_transactionsCollection).doc(transactionId);

      await _firestore.runTransaction((transaction) async {
        final txnSnap = await transaction.get(txnRef);
        if (!txnSnap.exists) {
          throw Exception('Transaction not found');
        }
        final txnData = txnSnap.data() as Map<String, dynamic>;

        if (txnData['status'] != TransactionStatus.pending) {
          throw Exception('This withdrawal has already been actioned');
        }

        final String userId = txnData['userId'];
        final double amount = (txnData['amount'] ?? 0).toDouble();
        final userRef = _firestore.collection(_usersCollection).doc(userId);

        await transaction.get(userRef);

        transaction.update(txnRef, {
          'status': TransactionStatus.confirmed,
          'confirmedAt': FieldValue.serverTimestamp(),
          'confirmedBy': adminId,
        });

        transaction.set(
          userRef,
          {'pendingWithdrawal': FieldValue.increment(-amount)},
          SetOptions(merge: true),
        );
      });

      return {'success': true, 'message': 'Withdrawal confirmed as paid'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to confirm withdrawal: $e'};
    }
  }

  // Admin rejects a withdrawal (e.g. wrong number given) - refunds the
  // held amount back into the user's spendable balance.
  Future<Map<String, dynamic>> rejectWithdrawal({
    required String transactionId,
    required String adminId,
  }) async {
    try {
      final txnRef =
          _firestore.collection(_transactionsCollection).doc(transactionId);

      await _firestore.runTransaction((transaction) async {
        final txnSnap = await transaction.get(txnRef);
        if (!txnSnap.exists) {
          throw Exception('Transaction not found');
        }
        final txnData = txnSnap.data() as Map<String, dynamic>;

        if (txnData['status'] != TransactionStatus.pending) {
          throw Exception('This withdrawal has already been actioned');
        }

        final String userId = txnData['userId'];
        final double amount = (txnData['amount'] ?? 0).toDouble();
        final userRef = _firestore.collection(_usersCollection).doc(userId);

        await transaction.get(userRef);

        transaction.update(txnRef, {
          'status': TransactionStatus.rejected,
          'confirmedAt': FieldValue.serverTimestamp(),
          'confirmedBy': adminId,
        });

        transaction.set(
          userRef,
          {
            'pendingWithdrawal': FieldValue.increment(-amount),
            'walletBalance': FieldValue.increment(amount),
          },
          SetOptions(merge: true),
        );
      });

      return {
        'success': true,
        'message': 'Withdrawal rejected and refunded to wallet'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to reject withdrawal: $e'};
    }
  }
}
