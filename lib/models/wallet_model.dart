import 'package:cloud_firestore/cloud_firestore.dart';

// Type of wallet transaction - a deposit adds money, a withdrawal takes it out
class TransactionType {
  static const String deposit = 'deposit';
  static const String withdrawal = 'withdrawal';
}

// Status of a transaction while the admin manually verifies real mobile-money movement
class TransactionStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String rejected = 'rejected';
}

// Represents one deposit or withdrawal request.
// Nothing here moves real money - it only records what the user CLAIMS
// they sent/want, until an admin manually confirms it against their own
// mobile money app and taps Confirm.
class WalletTransactionModel {
  final String id;
  final String userId;
  final String userName;
  final String type; // deposit or withdrawal - see TransactionType
  final double amount; // amount the user requested
  final double?
      netAmountToSend; // withdrawals only - amount after the 12% charge
  final String? momoNumber; // user's number: where they sent from (deposit)
                           // or where the admin should send to (withdrawal)
  final String? reference; // e.g. "JCS-1234-ABC" - quoted by the user when
                           // sending money so the admin can match it
  final String status; // pending, confirmed, rejected - see TransactionStatus
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? confirmedBy; // admin uid who actioned this

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.amount,
    this.netAmountToSend,
    this.momoNumber,
    this.reference,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    this.confirmedBy,
  });

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      type: data['type'] ?? TransactionType.deposit,
      amount: (data['amount'] ?? 0).toDouble(),
      netAmountToSend: data['netAmountToSend'] != null
          ? (data['netAmountToSend'] as num).toDouble()
          : null,
      momoNumber: data['momoNumber'],
      reference: data['reference'],
      status: data['status'] ?? TransactionStatus.pending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      confirmedBy: data['confirmedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'type': type,
      'amount': amount,
      'netAmountToSend': netAmountToSend,
      'momoNumber': momoNumber,
      'reference': reference,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedAt': null,
      'confirmedBy': null,
    };
  }
}
