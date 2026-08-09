import 'package:cloud_firestore/cloud_firestore.dart';

enum BetStatus { pending, won, lost, refunded, cancelled }

class BetModel {
  final String id;
  final String userId;
  final String userName;
  final String userMomoNumber;
  final String matchId;
  final String matchName;
  final String betTeam;
  final String betTeamName;
  final int amount;
  final double oddsAtPlacement;
  final int potentialWinnings;
  final BetStatus status;
  final String? reference;
  final String? description;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? settledBy;

  BetModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userMomoNumber,
    required this.matchId,
    required this.matchName,
    required this.betTeam,
    required this.betTeamName,
    required this.amount,
    required this.oddsAtPlacement,
    required this.potentialWinnings,
    required this.status,
    this.reference,
    this.description,
    required this.createdAt,
    this.settledAt,
    this.settledBy,
  });

  factory BetModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BetModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userMomoNumber: data['userMomoNumber'] ?? '',
      matchId: data['matchId'] ?? '',
      matchName: data['description']?.split(' in ').last ?? data['matchName'] ?? '',
      betTeam: data['betTeam'] ?? '',
      betTeamName: data['betTeamName'] ?? '',
      amount: data['amount'] ?? 0,
      oddsAtPlacement: (data['oddsAtPlacement'] ?? 1.5).toDouble(),
      potentialWinnings: data['potentialWinnings'] ?? 0,
      status: _parseStatus(data['status']),
      reference: data['reference'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt: data['settledAt'] != null ? (data['settledAt'] as Timestamp).toDate() : null,
      settledBy: data['settledBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'status': status.name,
      'reference': reference,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'settledBy': settledBy,
    };
  }

  static BetStatus _parseStatus(String? value) {
    switch (value) {
      case 'won':
        return BetStatus.won;
      case 'lost':
        return BetStatus.lost;
      case 'refunded':
        return BetStatus.refunded;
      case 'cancelled':
        return BetStatus.cancelled;
      case 'pending':
      default:
        return BetStatus.pending;
    }
  }
}
