import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_model.dart';
import '../utils/formatters.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String adminMomoNumber = '0768658988';
  static const String adminMomoName = 'Drake Wanswa';
  static const int minimumDeposit = 1000;
  static const int maximumDeposit = 50000;
  static const int minimumBet = 500;
  static const int maximumBet = 20000;
  static const int minimumWithdrawal = 1000;
  static const int maximumWithdrawalPerDay = 100000;
  static const double withdrawalFeePercent = 0.12;
  static const int depositReferenceExpiryMinutes = 120;
  static const int bettingWindowMinutes = 10;
  static const int winningsHoldHours = 24;
  static const List<String> validMomoPrefixes = [
    '077',
    '078',
    '076',
    '075',
    '070',
    '039',
    '031'
  ];

  bool isValidMomoNumber(String number) {
    final cleaned = number.replaceAll(' ', '').replaceAll('-', '');
    if (cleaned.length != 10) return false;
    return validMomoPrefixes.any((p) => cleaned.startsWith(p));
  }

  String _generateReference(String userName) {
    final random = Random();
    final number = 1000 + random.nextInt(9000);
    final clean = userName.replaceAll(' ', '');
    final nameCode =
        clean.substring(0, clean.length >= 3 ? 3 : clean.length).toUpperCase();
    return 'JCS-$number-$nameCode';
  }

  Stream<int> getBalanceStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final total = data['walletBalance'] ?? 0;
        final locked = data['lockedBalance'] ?? 0;
        return ((total - locked) as int);
      }
      return 0;
    });
  }

  Future<int> getBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return ((data['walletBalance'] ?? 0) - (data['lockedBalance'] ?? 0))
            as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Stream<List<WalletTransaction>> getTransactionHistory(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => WalletTransaction.fromFirestore(d)).toList());
  }

  Stream<List<WalletTransaction>> getPendingDeposits() {
    return _firestore
        .collection('transactions')
        .where('type', isEqualTo: TransactionType.deposit)
        .where('status', isEqualTo: TransactionStatus.pending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => WalletTransaction.fromFirestore(d)).toList());
  }

  Stream<List<WalletTransaction>> getPendingWithdrawals() {
    return _firestore
        .collection('transactions')
        .where('type', isEqualTo: TransactionType.withdrawal)
        .where('status', isEqualTo: TransactionStatus.pending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => WalletTransaction.fromFirestore(d)).toList());
  }

  // ── DEPOSIT ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createDepositRequest({
    required String userId,
    required String userName,
    required String userMomoNumber,
    required int amount,
  }) async {
    if (!isValidMomoNumber(userMomoNumber)) {
      return {
        'success': false,
        'message': 'Invalid MoMo number. Must be a valid Uganda number.'
      };
    }
    if (amount < minimumDeposit) {
      return {
        'success': false,
        'message': 'Minimum deposit is $minimumDeposit UGX'
      };
    }
    if (amount > maximumDeposit) {
      return {
        'success': false,
        'message': 'Maximum deposit is ${_fmt(maximumDeposit)} UGX'
      };
    }

    // Check existing pending deposit
    final existingPending = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: TransactionType.deposit)
        .where('status', isEqualTo: TransactionStatus.pending)
        .get();

    if (existingPending.docs.isNotEmpty) {
      final d = existingPending.docs.first.data();
      final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final age = DateTime.now().difference(createdAt).inMinutes;
        if (age < depositReferenceExpiryMinutes) {
          return {
            'success': false,
            'message':
                'You have a pending deposit. Wait ${depositReferenceExpiryMinutes - age} minutes for it to expire.'
          };
        } else {
          await _firestore
              .collection('transactions')
              .doc(existingPending.docs.first.id)
              .update({'status': TransactionStatus.expired});
        }
      }
    }

    // Max 3 per day - client side filter
    final allUserDeposits = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: TransactionType.deposit)
        .get();

    final todayStart =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayCount = allUserDeposits.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(todayStart);
    }).length;

    if (todayCount >= 3) {
      return {
        'success': false,
        'message': 'Maximum 3 deposit requests per day. Try again tomorrow.'
      };
    }

    try {
      final reference = _generateReference(userName);
      final expiresAt =
          DateTime.now().add(const Duration(minutes: depositReferenceExpiryMinutes));

      await _firestore.collection('transactions').add({
        'userId': userId,
        'userName': userName,
        'userMomoNumber': userMomoNumber,
        'type': TransactionType.deposit,
        'amount': amount,
        'actualAmountReceived': 0,
        'status': TransactionStatus.pending,
        'reference': reference,
        'description': 'Wallet deposit via MTN MoMo',
        'matchId': '',
        'betTeam': '',
        'fee': 0,
        'netAmount': amount,
        'creditIssued': false,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'reference': reference,
        'expiresAt': expiresAt,
        'message': 'Deposit request created'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create deposit: $e'};
    }
  }

  // Atomic confirm - prevents double crediting even with multiple taps
  Future<Map<String, dynamic>> confirmDeposit(
    WalletTransaction transaction, {
    required int actualAmountReceived,
  }) async {
    if (actualAmountReceived <= 0) {
      return {
        'success': false,
        'message': 'Please enter the actual amount received'
      };
    }

    bool alreadyCredited = false;

    try {
      await _firestore.runTransaction((txn) async {
        final txRef = _firestore.collection('transactions').doc(transaction.id);
        final txDoc = await txn.get(txRef);
        if (!txDoc.exists) throw Exception('Transaction not found');

        final txData = txDoc.data() as Map<String, dynamic>;

        // Atomic check - if already credited inside transaction, abort
        if (txData['creditIssued'] == true) {
          alreadyCredited = true;
          return;
        }

        final expiresAt = (txData['expiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          throw Exception('expired');
        }

        final userRef = _firestore.collection('users').doc(transaction.userId);

        txn.update(txRef, {
          'status': TransactionStatus.confirmed,
          'actualAmountReceived': actualAmountReceived,
          'creditIssued': true,
          'confirmedAt': FieldValue.serverTimestamp(),
        });

        txn.update(userRef, {
          'walletBalance': FieldValue.increment(actualAmountReceived),
        });
      });

      if (alreadyCredited) {
        return {
          'success': false,
          'message': 'Already credited. Cannot confirm twice.'
        };
      }

      return {
        'success': true,
        'message':
            '${_fmt(actualAmountReceived)} UGX credited to ${transaction.userName}\'s wallet',
      };
    } catch (e) {
      if (e.toString().contains('expired')) {
        return {
          'success': false,
          'message': 'This deposit request has expired.'
        };
      }
      return {'success': false, 'message': 'Failed: $e'};
    }
  }

  Future<void> rejectDeposit(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).update({
      'status': TransactionStatus.rejected,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── BETTING ──────────────────────────────────────────────────────────────

  // Place bet using admin-set fixed odds
  Future<Map<String, dynamic>> placeBet({
    required String userId,
    required String userName,
    required String userMomoNumber,
    required String matchId,
    required String matchName,
    required String betTeam,
    required String betTeamName,
    required int amount,
  }) async {
    try {
      if (amount < minimumBet) {
        return {'success': false, 'message': 'Minimum bet is $minimumBet UGX'};
      }
      if (amount > maximumBet) {
        return {
          'success': false,
          'message': 'Maximum bet is ${_fmt(maximumBet)} UGX'
        };
      }

      final matchDoc =
          await _firestore.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) {
        return {'success': false, 'message': 'Match not found'};
      }

      final matchData = matchDoc.data() as Map<String, dynamic>;

      // Check betting window
      final matchDate = (matchData['matchDate'] as Timestamp?)?.toDate();
      if (matchDate != null) {
        final bettingDeadline =
            matchDate.add(const Duration(minutes: bettingWindowMinutes));
        if (DateTime.now().isAfter(bettingDeadline)) {
          return {
            'success': false,
            'message':
                'Betting is closed. Only allowed before kick-off and first 10 minutes.'
          };
        }
      }

      if (matchData['status'] == 'completed' ||
          matchData['status'] == 'cancelled') {
        return {'success': false, 'message': 'This match is already settled.'};
      }
      if (matchData['isFrozen'] == true) {
        return {
          'success': false,
          'message': 'Betting on this match has been suspended by admin.'
        };
      }
      if (matchData['winnersDistributed'] == true) {
        return {
          'success': false,
          'message': 'This match has already been paid out.'
        };
      }

      // One bet per match
      final existingBet = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('matchId', isEqualTo: matchId)
          .where('type', isEqualTo: TransactionType.bet)
          .get();

      if (existingBet.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You have already placed a bet on this match.'
        };
      }

      // Admin cannot bet
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['isAdmin'] == true) {
        return {
          'success': false,
          'message': 'Admin accounts cannot place bets.'
        };
      }

      // Check available balance
      final total = (userData['walletBalance'] ?? 0) as int;
      final locked = (userData['lockedBalance'] ?? 0) as int;
      final available = total - locked;
      if (available < amount) {
        return {
          'success': false,
          'message': 'Insufficient balance. Available: ${_fmt(available)} UGX'
        };
      }

      // Get admin-set odds for this bet
      final double oddsAtPlacement = betTeam == 'A'
          ? (matchData['oddsA'] ?? 1.5).toDouble()
          : (matchData['oddsB'] ?? 2.0).toDouble();

      // Potential winnings = bet amount × odds
      final int potentialWinnings = (amount * oddsAtPlacement).floor();
      final String reference = _generateReference(userName);

      await _firestore.runTransaction((txn) async {
        final userRef = _firestore.collection('users').doc(userId);
        final matchRef = _firestore.collection('matches').doc(matchId);
        final betRef = _firestore.collection('transactions').doc();

        txn.set(betRef, {
          'userId': userId,
          'userName': userName,
          'userMomoNumber': userMomoNumber,
          'type': TransactionType.bet,
          'amount': amount,
          'fee': 0,
          'netAmount': amount,
          'status': TransactionStatus.confirmed,
          'reference': reference,
          'description': 'Bet on $betTeamName in $matchName',
          'matchId': matchId,
          'betTeam': betTeam,
          'oddsAtPlacement': oddsAtPlacement,
          'potentialWinnings': potentialWinnings,
          'creditIssued': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        txn.update(userRef, {
          'walletBalance': FieldValue.increment(-amount),
        });

        txn.update(matchRef, {
          'bets.$userId': {
            'userName': userName,
            'userMomoNumber': userMomoNumber,
            'team': betTeam,
            'teamName': betTeamName,
            'amount': amount,
            'oddsAtPlacement': oddsAtPlacement,
            'potentialWinnings': potentialWinnings,
          },
          'totalPool': FieldValue.increment(amount),
          'votedBy': FieldValue.arrayUnion([userId]),
          'userVotes.$userId': betTeam,
          if (betTeam == 'A') 'votesA': FieldValue.increment(1),
          if (betTeam == 'B') 'votesB': FieldValue.increment(1),
          if (betTeam == 'A') 'poolA': FieldValue.increment(amount),
          if (betTeam == 'B') 'poolB': FieldValue.increment(amount),
        });
      });

      // Create bet document in bets collection after transaction succeeds
      try {
        await _firestore.collection('bets').add({
          'userId': userId,
          'userName': userName,
          'userMomoNumber': userMomoNumber,
          'matchId': matchId,
          'matchName': matchName,
          'betTeam': betTeam,
          'betTeamName': betTeamName,
          'amount': amount,
          'oddsAtPlacement': oddsAtPlacement,
          'potentialWinnings': potentialWinnings,
          'status': 'pending',
          'reference': reference,
          'description': 'Bet on $betTeamName in $matchName',
          'createdAt': FieldValue.serverTimestamp(),
          'settledAt': null,
          'settledBy': null,
        });
      } catch (e) {
        // Bet doc creation failed but wallet transaction succeeded
        // User can still see bet in transaction history
      }

      return {
        'success': true,
        'message':
            'Bet placed! ${_fmt(amount)} UGX deducted.\nOdds: ${oddsAtPlacement.toStringAsFixed(2)}x | If you win: ${_fmt(potentialWinnings)} UGX',
        'odds': oddsAtPlacement,
        'potentialWinnings': potentialWinnings,
        'reference': reference,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to place bet: $e'};
    }
  }

  // Distribute winnings using fixed odds stored on each bet
  Future<Map<String, dynamic>> distributeWinnings({
    required String matchId,
    required String winnerTeam,
    required String adminId,
    required String confirmationText,
  }) async {
    try {
      if (confirmationText.trim() != matchId.trim()) {
        return {
          'success': false,
          'message': 'Confirmation failed. Type the exact match ID.'
        };
      }

      final matchDoc =
          await _firestore.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) {
        return {'success': false, 'message': 'Match not found'};
      }

      final matchData = matchDoc.data() as Map<String, dynamic>;

      if (matchData['winnersDistributed'] == true) {
        return {
          'success': false,
          'message': 'Winnings already distributed for this match.'
        };
      }

      final Map<String, dynamic> bets =
          Map<String, dynamic>.from(matchData['bets'] ?? {});
      if (bets.isEmpty) {
        return {'success': false, 'message': 'No bets on this match'};
      }

      if (winnerTeam == 'CANCELLED') {
        return await _refundAllBets(
            matchId: matchId, bets: bets, adminId: adminId);
      }

      final WriteBatch batch = _firestore.batch();
      final List<Map<String, dynamic>> receiptLines = [];
      final withdrawableAfter =
          DateTime.now().add(const Duration(hours: winningsHoldHours));

      final allMatchBets = await _firestore
          .collection('bets')
          .where('matchId', isEqualTo: matchId)
          .get();

      // Pay winners based on their fixed odds at placement time
      bets.forEach((userId, betData) {
        if (betData['team'] == winnerTeam) {
          final int winnings = (betData['potentialWinnings'] as int? ?? 0);

          final userRef = _firestore.collection('users').doc(userId);
          batch.update(userRef, {
            'walletBalance': FieldValue.increment(winnings),
          });

          final winRef = _firestore.collection('transactions').doc();
          batch.set(winRef, {
            'userId': userId,
            'userName': betData['userName'],
            'userMomoNumber': betData['userMomoNumber'],
            'type': TransactionType.winnings,
            'amount': winnings,
            'fee': 0,
            'netAmount': winnings,
            'status': TransactionStatus.confirmed,
            'reference': 'WIN-${matchId.substring(0, 6)}',
            'description':
                'Match winnings at ${betData['oddsAtPlacement']}x odds',
            'matchId': matchId,
            'betTeam': winnerTeam,
            'creditIssued': true,
            'withdrawableAfter': Timestamp.fromDate(withdrawableAfter),
            'createdAt': FieldValue.serverTimestamp(),
          });

          receiptLines.add({
            'userName': betData['userName'],
            'momoNumber': betData['userMomoNumber'],
            'betAmount': betData['amount'],
            'odds': betData['oddsAtPlacement'],
            'winnings': winnings,
            'team': betData['teamName'] ?? winnerTeam,
          });
        }
      });

      // Update bet statuses in bets collection
      for (final betDoc in allMatchBets.docs) {
        final betTeam = betDoc.data()['betTeam'] ?? '';
        final newStatus = betTeam == winnerTeam ? 'won' : 'lost';
        batch.update(betDoc.reference, {
          'status': newStatus,
          'settledAt': FieldValue.serverTimestamp(),
          'settledBy': adminId,
        });
      }

      final matchRef = _firestore.collection('matches').doc(matchId);
      batch.update(matchRef, {
        'winnersDistributed': true,
        'winnerTeam': winnerTeam,
        'distributedAt': FieldValue.serverTimestamp(),
        'distributedBy': adminId,
        'distributionReceipt': receiptLines,
        'status': 'completed',
      });

      await batch.commit();

      final int totalWinnersPaid =
          receiptLines.fold(0, (sum, r) => sum + (r['winnings'] as int));
      final int totalPool = matchData['totalPool'] ?? 0;
      final int adminProfit = totalPool - totalWinnersPaid;

      final summary = receiptLines
          .map((r) =>
              '${r['userName']} (${r['momoNumber']}): ${_fmt(r['winnings'] as int)} UGX')
          .join('\n');

      return {
        'success': true,
        'message':
            'Done! ${receiptLines.length} winners paid.\n$summary\n\nTotal collected: ${_fmt(totalPool)} UGX\nTotal paid out: ${_fmt(totalWinnersPaid)} UGX\nYour profit: ${_fmt(adminProfit)} UGX',
        'receipt': receiptLines,
        'adminProfit': adminProfit,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Distribution failed: $e. No money moved.'
      };
    }
  }

  Future<Map<String, dynamic>> _refundAllBets({
    required String matchId,
    required Map<String, dynamic> bets,
    required String adminId,
  }) async {
    try {
      final WriteBatch batch = _firestore.batch();

      final allMatchBets = await _firestore
          .collection('bets')
          .where('matchId', isEqualTo: matchId)
          .get();

      bets.forEach((userId, betData) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef,
            {'walletBalance': FieldValue.increment(betData['amount'] as int)});

        final refundRef = _firestore.collection('transactions').doc();
        batch.set(refundRef, {
          'userId': userId,
          'userName': betData['userName'],
          'userMomoNumber': betData['userMomoNumber'],
          'type': TransactionType.refund,
          'amount': betData['amount'],
          'fee': 0,
          'netAmount': betData['amount'],
          'status': TransactionStatus.confirmed,
          'reference': 'REFUND-${matchId.substring(0, 6)}',
          'description': 'Full refund - match cancelled',
          'matchId': matchId,
          'betTeam': betData['team'],
          'creditIssued': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      for (final betDoc in allMatchBets.docs) {
        batch.update(betDoc.reference, {
          'status': 'refunded',
          'settledAt': FieldValue.serverTimestamp(),
          'settledBy': adminId,
        });
      }

      final matchRef = _firestore.collection('matches').doc(matchId);
      batch.update(matchRef, {
        'winnersDistributed': true,
        'winnerTeam': 'CANCELLED',
        'status': 'cancelled',
        'distributedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        'success': true,
        'message':
            'Match cancelled. Full refunds issued to all ${bets.length} bettors.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Refund failed: $e'};
    }
  }

  // ── WITHDRAWAL ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestWithdrawal({
    required String userId,
    required String userName,
    required String userMomoNumber,
    required int amount,
  }) async {
    try {
      if (!isValidMomoNumber(userMomoNumber)) {
        return {
          'success': false,
          'message': 'Invalid MoMo number. Enter a valid Uganda number.'
        };
      }
      if (amount < minimumWithdrawal) {
        return {
          'success': false,
          'message': 'Minimum withdrawal is ${_fmt(minimumWithdrawal)} UGX'
        };
      }

      // Daily limit - client side
      final allWithdrawals = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: TransactionType.withdrawal)
          .get();

      final todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int todayTotal = 0;
      for (final doc in allWithdrawals.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(todayStart)) {
          todayTotal += (data['amount'] as int? ?? 0);
        }
      }
      if (todayTotal + amount > maximumWithdrawalPerDay) {
        return {
          'success': false,
          'message':
              'Daily limit is ${_fmt(maximumWithdrawalPerDay)} UGX. Used ${_fmt(todayTotal)} UGX today.'
        };
      }

      // 24h hold on winnings
      final winnings = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: TransactionType.winnings)
          .get();

      for (final doc in winnings.docs) {
        final data = doc.data();
        final withdrawableAfter =
            (data['withdrawableAfter'] as Timestamp?)?.toDate();
        if (withdrawableAfter != null &&
            DateTime.now().isBefore(withdrawableAfter)) {
          final hoursLeft =
              withdrawableAfter.difference(DateTime.now()).inHours;
          return {
            'success': false,
            'message':
                'Winnings under 24h security hold. Available in ${hoursLeft}h.'
          };
        }
      }

      // Check available balance
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }
      final userData = userDoc.data() as Map<String, dynamic>;
      final total = (userData['walletBalance'] ?? 0) as int;
      final locked = (userData['lockedBalance'] ?? 0) as int;
      final available = total - locked;
      if (available < amount) {
        return {
          'success': false,
          'message': 'Insufficient balance. Available: ${_fmt(available)} UGX'
        };
      }

      final int fee = (amount * withdrawalFeePercent).floor();
      final int netAmount = amount - fee;

      await _firestore.runTransaction((txn) async {
        final userRef = _firestore.collection('users').doc(userId);
        final withdrawRef = _firestore.collection('transactions').doc();

        txn.update(userRef, {
          'walletBalance': FieldValue.increment(-amount),
          'lockedBalance': FieldValue.increment(amount),
        });

        txn.set(withdrawRef, {
          'userId': userId,
          'userName': userName,
          'userMomoNumber': userMomoNumber,
          'type': TransactionType.withdrawal,
          'amount': amount,
          'fee': fee,
          'netAmount': netAmount,
          'status': TransactionStatus.pending,
          'reference': _generateReference(userName),
          'description': 'Withdrawal to $userMomoNumber',
          'matchId': '',
          'betTeam': '',
          'creditIssued': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      return {
        'success': true,
        'message':
            'Withdrawal requested!\nAmount: ${_fmt(amount)} UGX\nFee (12%): ${_fmt(fee)} UGX\nYou receive: ${_fmt(netAmount)} UGX to $userMomoNumber within 24h.',
        'fee': fee,
        'netAmount': netAmount,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed: $e'};
    }
  }

  Future<void> confirmWithdrawal(WalletTransaction transaction) async {
    await _firestore.runTransaction((txn) async {
      final txRef = _firestore.collection('transactions').doc(transaction.id);
      final userRef = _firestore.collection('users').doc(transaction.userId);
      txn.update(txRef, {
        'status': TransactionStatus.confirmed,
        'confirmedAt': FieldValue.serverTimestamp()
      });
      txn.update(userRef,
          {'lockedBalance': FieldValue.increment(-transaction.amount)});
    });
  }

  Future<void> rejectWithdrawal(WalletTransaction transaction) async {
    await _firestore.runTransaction((txn) async {
      final txRef = _firestore.collection('transactions').doc(transaction.id);
      final userRef = _firestore.collection('users').doc(transaction.userId);
      txn.update(txRef, {'status': TransactionStatus.rejected});
      txn.update(userRef, {
        'walletBalance': FieldValue.increment(transaction.amount),
        'lockedBalance': FieldValue.increment(-transaction.amount),
      });
    });
  }

  // Get admin odds for a match (used in bet dialog)
  Future<Map<String, double>> getMatchOdds(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) return {'A': 1.5, 'B': 2.0};
      final data = doc.data() as Map<String, dynamic>;
      return {
        'A': (data['oddsA'] ?? 1.5).toDouble(),
        'B': (data['oddsB'] ?? 2.0).toDouble(),
      };
    } catch (e) {
      return {'A': 1.5, 'B': 2.0};
    }
  }

  // Get bets summary for a match - used in admin accountability dashboard
  Future<Map<String, dynamic>> getMatchBetsSummary(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>;
      final bets = Map<String, dynamic>.from(data['bets'] ?? {});
      final int totalPool = data['totalPool'] ?? 0;
      final int poolA = data['poolA'] ?? 0;
      final int poolB = data['poolB'] ?? 0;
      final double oddsA = (data['oddsA'] ?? 1.5).toDouble();
      final double oddsB = (data['oddsB'] ?? 2.0).toDouble();

      // Calculate total liability if Team A wins
      int liabilityA = 0;
      int liabilityB = 0;
      bets.forEach((userId, betData) {
        if (betData['team'] == 'A') {
          liabilityA += (betData['potentialWinnings'] as int? ?? 0);
        } else {
          liabilityB += (betData['potentialWinnings'] as int? ?? 0);
        }
      });

      return {
        'bets': bets,
        'totalPool': totalPool,
        'poolA': poolA,
        'poolB': poolB,
        'oddsA': oddsA,
        'oddsB': oddsB,
        'totalBettors': bets.length,
        'bettorsA': bets.values.where((b) => b['team'] == 'A').length,
        'bettorsB': bets.values.where((b) => b['team'] == 'B').length,
        'liabilityIfAWins': liabilityA,
        'liabilityIfBWins': liabilityB,
        'profitIfAWins': totalPool - liabilityA,
        'profitIfBWins': totalPool - liabilityB,
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> getUserBetSummary(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('userId', isEqualTo: userId)
          .get();

      int active = 0;
      int won = 0;
      int lost = 0;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'pending';
        if (status == 'pending') active++;
        if (status == 'won') won++;
        if (status == 'lost') lost++;
      }

      return {
        'active': active,
        'won': won,
        'lost': lost,
      };
    } catch (e) {
      return {'active': 0, 'won': 0, 'lost': 0};
    }
  }

  Future<Map<String, dynamic>> syncUserBets(String userId) async {
    try {
      final betTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: TransactionType.bet)
          .get();

      int synced = 0;
      for (final txDoc in betTransactions.docs) {
        final txData = txDoc.data();
        final matchId = txData['matchId'] ?? '';
        if (matchId.isEmpty) continue;

        final existing = await _firestore
            .collection('bets')
            .where('userId', isEqualTo: userId)
            .where('matchId', isEqualTo: matchId)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          await _firestore.collection('bets').add({
            'userId': txData['userId'],
            'userName': txData['userName'],
            'userMomoNumber': txData['userMomoNumber'],
            'matchId': matchId,
            'matchName': txData['description'] ?? '',
            'betTeam': txData['betTeam'] ?? '',
            'betTeamName': txData['betTeam'] ?? '',
            'amount': txData['amount'],
            'oddsAtPlacement': txData['oddsAtPlacement'] ?? 1.5,
            'potentialWinnings': txData['potentialWinnings'] ?? 0,
            'status': 'pending',
            'reference': txData['reference'],
            'description': txData['description'],
            'createdAt': txData['createdAt'],
            'settledAt': null,
            'settledBy': null,
          });
          synced++;
        }
      }

      return {'success': true, 'synced': synced};
    } catch (e) {
      return {'success': false, 'message': 'Sync failed: $e'};
    }
  }

  String _fmt(int amount) {
    return formatCurrency(amount);
  }
}
