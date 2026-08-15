import 'package:cloud_firestore/cloud_firestore.dart';

// Status of betting on a particular match.
// This is DELIBERATELY separate from MatchStatus in match_model.dart -
// a match's live score status (upcoming/live/completed) and its betting
// status are two different things. A match can be 'completed' on the
// scoreboard while its bets are still waiting to be settled by an admin.
class BettingStatus {
  static const String open = 'open'; // users can place bets
  static const String ended = 'ended'; // admin stopped betting, not yet settled
  static const String settled = 'settled'; // winners paid out
}

// One MatchBettingModel per match, stored in its own 'match_betting'
// collection, keyed by the same id as the match it belongs to.
// This keeps the existing 'matches' collection/model completely untouched.
class MatchBettingModel {
  final String matchId;
  final double oddsA; // payout multiplier if Team A wins
  final double oddsB; // payout multiplier if Team B wins
  final String status; // open, ended, settled - see BettingStatus
  final String? winningSelection; // 'A' or 'B', set once settled
  final DateTime? endedAt;
  final DateTime? settledAt;

  const MatchBettingModel({
    required this.matchId,
    required this.oddsA,
    required this.oddsB,
    required this.status,
    this.winningSelection,
    this.endedAt,
    this.settledAt,
  });

  factory MatchBettingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MatchBettingModel(
      matchId: doc.id,
      oddsA: (data['oddsA'] ?? 2).toDouble(),
      oddsB: (data['oddsB'] ?? 2).toDouble(),
      status: data['status'] ?? BettingStatus.open,
      winningSelection: data['winningSelection'],
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oddsA': oddsA,
      'oddsB': oddsB,
      'status': status,
      'winningSelection': winningSelection,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
    };
  }
}
