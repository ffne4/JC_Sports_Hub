import 'package:cloud_firestore/cloud_firestore.dart';

// Status a bet can be in at any point in time
// Same pattern as MatchStatus in match_model.dart - constants instead of raw strings
class BetStatus {
  static const String pending = 'pending';
  static const String won = 'won';
  static const String lost = 'lost';
}

// Represents a single bet placed by a user on a match.
// One BetModel = one "ticket". A user can place many bets on the same match
// (e.g. changing their mind isn't allowed, but nothing stops a second bet).
class BetModel {
  final String id;
  final String userId;
  final String userName; // saved at bet time so admin doesn't need a join
  final String matchId;
  final String matchLabel; // e.g. "Basoga Nsete vs Northerners" - for display
  final String selection; // 'A' or 'B' - which team the user backed
  final double stakeAmount; // how much was deducted from the wallet
  final double odds; // odds locked in at the moment the bet was placed
  final double
      potentialWinnings; // stakeAmount * odds, stored, not recalculated later
  final String status; // pending, won, lost - see BetStatus
  final DateTime placedAt;
  final DateTime? settledAt;

  const BetModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.matchId,
    required this.matchLabel,
    required this.selection,
    required this.stakeAmount,
    required this.odds,
    required this.potentialWinnings,
    required this.status,
    required this.placedAt,
    this.settledAt,
  });

  factory BetModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BetModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      matchId: data['matchId'] ?? '',
      matchLabel: data['matchLabel'] ?? '',
      selection: data['selection'] ?? 'A',
      stakeAmount: (data['stakeAmount'] ?? 0).toDouble(),
      odds: (data['odds'] ?? 1).toDouble(),
      potentialWinnings: (data['potentialWinnings'] ?? 0).toDouble(),
      status: data['status'] ?? BetStatus.pending,
      placedAt: (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'matchId': matchId,
      'matchLabel': matchLabel,
      'selection': selection,
      'stakeAmount': stakeAmount,
      'odds': odds,
      'potentialWinnings': potentialWinnings,
      'status': status,
      'placedAt': FieldValue.serverTimestamp(),
      'settledAt': null,
    };
  }
}
