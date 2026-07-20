import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String rejected = 'rejected';
  static const String expired = 'expired';
}

class TransactionType {
  static const String deposit = 'deposit';
  static const String bet = 'bet';
  static const String winnings = 'winnings';
  static const String withdrawal = 'withdrawal';
  static const String refund = 'refund';
}

class WalletTransaction {
  final String id;
  final String userId;
  final String userName;
  final String userMomoNumber;
  final String type;
  final int amount;
  final int fee;
  final int netAmount;
  final String status;
  final String reference;
  final String description;
  final String matchId;
  final String betTeam;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userMomoNumber,
    required this.type,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.status,
    required this.reference,
    required this.description,
    required this.matchId,
    required this.betTeam,
    required this.createdAt,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userMomoNumber: data['userMomoNumber'] ?? '',
      type: data['type'] ?? TransactionType.deposit,
      amount: data['amount'] ?? 0,
      fee: data['fee'] ?? 0,
      netAmount: data['netAmount'] ?? 0,
      status: data['status'] ?? TransactionStatus.pending,
      reference: data['reference'] ?? '',
      description: data['description'] ?? '',
      matchId: data['matchId'] ?? '',
      betTeam: data['betTeam'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}