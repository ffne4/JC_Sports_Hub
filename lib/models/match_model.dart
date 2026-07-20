import 'package:cloud_firestore/cloud_firestore.dart';

class MatchStatus {
  static const String upcoming = 'upcoming';
  static const String live = 'live';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

class MatchModel {
  final String id;
  final String sport;
  final String teamA;
  final String teamB;
  final String venue;
  final DateTime matchDate;
  final String status;
  final int scoreA;
  final int scoreB;
  final String adminNotes;
  final double oddsA;       // Admin-set odds for Team A e.g. 1.8
  final double oddsB;       // Admin-set odds for Team B e.g. 2.2
  final int votesA;
  final int votesB;
  final int totalPool;
  final List<String> votedBy;
  final Map<String, String> userVotes;
  final Map<String, dynamic> bets;
  final bool winnersDistributed;
  final DateTime createdAt;

  const MatchModel({
    required this.id,
    required this.sport,
    required this.teamA,
    required this.teamB,
    required this.venue,
    required this.matchDate,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.adminNotes,
    required this.oddsA,
    required this.oddsB,
    required this.votesA,
    required this.votesB,
    required this.totalPool,
    required this.votedBy,
    required this.userVotes,
    required this.bets,
    required this.winnersDistributed,
    required this.createdAt,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      sport: data['sport'] ?? 'Football',
      teamA: data['teamA'] ?? '',
      teamB: data['teamB'] ?? '',
      venue: data['venue'] ?? '',
      matchDate: (data['matchDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? MatchStatus.upcoming,
      scoreA: data['scoreA'] ?? 0,
      scoreB: data['scoreB'] ?? 0,
      adminNotes: data['adminNotes'] ?? '',
      oddsA: (data['oddsA'] ?? 1.5).toDouble(),
      oddsB: (data['oddsB'] ?? 2.0).toDouble(),
      votesA: data['votesA'] ?? 0,
      votesB: data['votesB'] ?? 0,
      totalPool: data['totalPool'] ?? 0,
      votedBy: List<String>.from(data['votedBy'] ?? []),
      userVotes: Map<String, String>.from(data['userVotes'] ?? {}),
      bets: Map<String, dynamic>.from(data['bets'] ?? {}),
      winnersDistributed: data['winnersDistributed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}