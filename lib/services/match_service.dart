import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'matches';

  Stream<List<MatchModel>> getAllMatches() {
    return _firestore
        .collection(_collection)
        .orderBy('matchDate', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => MatchModel.fromFirestore(d)).toList());
  }

  Stream<List<MatchModel>> getUpcomingMatches() {
    return _firestore
        .collection(_collection)
        .orderBy('matchDate', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MatchModel.fromFirestore(d))
            .where((m) => m.status == MatchStatus.upcoming)
            .toList());
  }

  Stream<List<MatchModel>> getLiveMatches() {
    return _firestore
        .collection(_collection)
        .orderBy('matchDate', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MatchModel.fromFirestore(d))
            .where((m) => m.status == MatchStatus.live)
            .toList());
  }

  Stream<List<MatchModel>> getCompletedMatches() {
    return _firestore
        .collection(_collection)
        .orderBy('matchDate', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MatchModel.fromFirestore(d))
            .where((m) =>
                m.status == MatchStatus.completed ||
                m.status == MatchStatus.cancelled)
            .toList());
  }

  // Schedule match with admin-set odds
  Future<Map<String, dynamic>> scheduleMatch({
    required String sport,
    required String teamA,
    required String teamB,
    required String venue,
    required DateTime matchDate,
    required double oddsA,
    required double oddsB,
    String adminNotes = '',
    String tournamentId = '',
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'sport': sport,
        'teamA': teamA,
        'teamB': teamB,
        'venue': venue,
        'matchDate': Timestamp.fromDate(matchDate),
        'status': MatchStatus.upcoming,
        'scoreA': 0,
        'scoreB': 0,
        'adminNotes': adminNotes,
        'oddsA': oddsA,
        'oddsB': oddsB,
        'votesA': 0,
        'votesB': 0,
        'totalPool': 0,
        'poolA': 0,
        'poolB': 0,
        // Betting pool counters (used by the Matches tracking screens).
        'betsCount': 0,
        'poolAmount': 0,
        'votedBy': [],
        'userVotes': {},
        'bets': {},
        'winnersDistributed': false,
        'isFrozen': false,
        // Optional linkage so tournament-sourced matches can be traced back.
        'tournamentId': tournamentId,
        'fixtureId': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {
        'success': true,
        'message': 'Match scheduled! Odds: Team A ${oddsA}x | Team B ${oddsB}x'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to schedule match: $e'};
    }
  }

  // Admin updates odds before betting opens
  Future<void> updateOdds(String matchId, double oddsA, double oddsB) async {
    await _firestore.collection(_collection).doc(matchId).update({
      'oddsA': oddsA,
      'oddsB': oddsB,
    });
  }

  // Admin freezes/unfreezes betting on a match
  Future<void> toggleFreeze(String matchId, bool freeze) async {
    await _firestore.collection(_collection).doc(matchId).update({
      'isFrozen': freeze,
    });
  }

  Future<Map<String, dynamic>> updateScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String status,
  }) async {
    try {
      await _firestore.collection(_collection).doc(matchId).update({
        'scoreA': scoreA,
        'scoreB': scoreB,
        'status': status,
      });
      return {'success': true, 'message': 'Score updated'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update score: $e'};
    }
  }

  // Bulk-imports verified inter-clan tournament fixtures (from
  // InterClanFixtureSeed) so the admin can seed the schedule in one tap.
  Future<Map<String, dynamic>> replaceAllFixtures(
      List<Map<String, dynamic>> fixtures) async {
    try {
      final batch = _firestore.batch();
      final fixturesCol = _firestore.collection('tournament_fixtures');
      for (final fixture in fixtures) {
        final id = fixture['id'] as String?;
        batch.set(
          id != null ? fixturesCol.doc(id) : fixturesCol.doc(),
          Map<String, dynamic>.from(fixture),
        );
      }
      await batch.commit();
      return {
        'success': true,
        'message': 'Imported ${fixtures.length} verified tournament fixtures'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to import fixtures: $e'};
    }
  }

  Future<void> deleteMatch(String matchId) async {
    await _firestore.collection(_collection).doc(matchId).delete();
  }
}
