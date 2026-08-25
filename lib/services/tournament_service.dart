import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/inter_clan_fixture_seed.dart';
import '../data/inter_clan_games_constants.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../utils/tournament_result_parser.dart';

/// Owns everything about tournaments: publishing, seeding the verified
/// workbook fixtures, capturing results, keeping the points table in sync,
/// student/tribe registration and in-app notifications.
class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');

  CollectionReference<Map<String, dynamic>> _squads(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('squads');

  CollectionReference<Map<String, dynamic>> _tribeRegistrations(
          String tournamentId) =>
      _tournaments.doc(tournamentId).collection('tribe_registrations');

  CollectionReference<Map<String, dynamic>> _fixtures(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('fixtures');

  CollectionReference<Map<String, dynamic>> _points(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('points');

  // ---------------------------------------------------------------------
  // CREATION / DELETION
  // ---------------------------------------------------------------------

  /// One-tap admin flow: publishes the verified Inter-Tribe Games 2026.
  Future<String> createInterClanGames2026({
    TournamentStatus status = TournamentStatus.upcoming,
  }) async {
    final tournament = TournamentModel.interClanGames2026(
      createdBy: _currentUserId ?? '',
      status: status,
    );
    return createTournament(tournament, useVerifiedSeed: true);
  }

  Future<String> createTournament(
    TournamentModel tournament, {
    bool useVerifiedSeed = false,
  }) async {
    final docRef = await _tournaments.add(tournament.toMap());
    if (useVerifiedSeed) {
      await _seedVerifiedFixtures(docRef.id);
    }
    await _initializePoints(docRef.id, tournament.tribes);
    await _initializeTribeRegistrations(docRef.id);
    await _notifyAllStudents(
        'New Tournament', '${tournament.name} has been published in the app.');
    return docRef.id;
  }

  Future<void> deleteTournament(String tournamentId) async {
    for (final sub in [
      _fixtures(tournamentId),
      _points(tournamentId),
      _squads(tournamentId),
      _tribeRegistrations(tournamentId),
    ]) {
      final snapshot = await sub.get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _tournaments.doc(tournamentId).delete();
  }

  // ---------------------------------------------------------------------
  // READING
  // ---------------------------------------------------------------------

  Stream<List<TournamentModel>> getActiveTournaments() {
    // `where` + `orderBy` on different fields needs a composite index which may
    // be absent, silently breaking the admin list ("no tournaments"). Sort in
    // Dart instead so this always works.
    return _tournaments
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // For the ADMIN panel - shows every tournament regardless of status so an
  // ended/completed tournament never disappears ("no tournaments created").
  Stream<List<TournamentModel>> getAdminTournaments() {
    return _tournaments.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<TournamentModel?> getCurrentTournament() {
    return _tournaments
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final list = snapshot.docs
          .map((doc) => TournamentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.first;
    });
  }

  Future<void> updateTournamentStatus(
      String tournamentId, TournamentStatus status) async {
    await _tournaments.doc(tournamentId).update({
      'status': status.name,
      'isActive': status != TournamentStatus.completed,
    });
  }

  Stream<List<TournamentFixture>> getAllFixtures(String tournamentId) {
    return _fixtures(tournamentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Admin edits a single fixture (date / game / teams / time slot). The change
  // goes straight back into the tournament's fixture document.
  Future<Map<String, dynamic>> updateFixture(
      String tournamentId, TournamentFixture fixture) async {
    try {
      await _fixtures(tournamentId).doc(fixture.id).set(fixture.toMap());
      return {'success': true, 'message': 'Fixture updated'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update fixture: $e'};
    }
  }

  // Turns a fixture's clock-time into a DateTime (defaults 9:00 AM if the
  // fixture has a time in its notes but an unknown slot).
  DateTime _fixtureDateTime(DateTime date, FixtureTimeSlot slot) {
    int hour = 9;
    switch (slot) {
      case FixtureTimeSlot.slot1_4pm:
        hour = 16;
        break;
      case FixtureTimeSlot.slot2_5pm:
        hour = 17;
        break;
      case FixtureTimeSlot.mind_3pm:
        hour = 15;
        break;
    }
    return DateTime(date.year, date.month, date.day, hour);
  }

  // Publishes every tournament fixture into the `matches` collection so the
  // admin's Matches tab (status / live score / odds / bets) and the users'
  // Matches screen can manage and display them exactly like scheduled matches.
  // Existing matches are only refreshed with the fixture basics so any admin
  // status/odds edits are preserved.
  Future<Map<String, dynamic>> publishFixturesToMatches(
      String tournamentId) async {
    try {
      final tournamentDoc = await _tournaments.doc(tournamentId).get();
      if (!tournamentDoc.exists) {
        return {'success': false, 'message': 'Tournament not found.'};
      }
      final tournament =
          TournamentModel.fromMap(tournamentDoc.data()!, tournamentId);

      final fixturesSnapshot = await _fixtures(tournamentId).get();
      if (fixturesSnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'No fixtures to publish.'};
      }

      final matchesCol = _db.collection('matches');
      final batch = _db.batch();
      var created = 0;
      var updated = 0;

      for (final doc in fixturesSnapshot.docs) {
        final fixture = TournamentFixture.fromMap(doc.data(), doc.id);
        final matchDocId = 'fixture_${fixture.id}';
        final matchDate = _fixtureDateTime(fixture.date, fixture.timeSlot);
        // Always refreshed (teams/venue/time) even on re-publish.
        final basics = <String, dynamic>{
          'sport': fixture.game,
          'teamA': fixture.homeClan,
          'teamB': fixture.awayClan,
          'venue': tournament.name,
          'matchDate': Timestamp.fromDate(matchDate),
        };

        final existing = await matchesCol.doc(matchDocId).get();
        if (existing.exists) {
          // Only refresh basics so admin odds / status / scores aren't wiped.
          batch.update(matchesCol.doc(matchDocId), basics);
          updated++;
        } else {
          batch.set(matchesCol.doc(matchDocId), {
            ...basics,
            'status': fixture.result != null
                ? MatchStatus.completed
                : MatchStatus.upcoming,
            'scoreA': fixture.homePts,
            'scoreB': fixture.awayPts,
            'adminNotes': '',
            'oddsA': 1.5,
            'oddsB': 2.0,
            'votesA': 0,
            'votesB': 0,
            'totalPool': 0,
            'poolA': 0,
            'poolB': 0,
            'votedBy': [],
            'userVotes': {},
            'bets': {},
            'winnersDistributed': false,
            'isFrozen': false,
            'tournamentId': tournamentId,
            'fixtureId': fixture.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
          created++;
        }
      }

      await batch.commit();
      return {
        'success': true,
        'message': 'Published $created fixture(s) to Matches${updated > 0 ? ', refreshed $updated existing' : ''}.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to publish fixtures: $e'};
    }
  }

  Stream<List<TournamentFixture>> getFixturesByMatchDay(
      String tournamentId, int matchDay) {
    return _fixtures(tournamentId)
        .where('matchDay', isEqualTo: matchDay)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.game.compareTo(b.game));
      return list;
    });
  }

  Stream<List<TournamentFixture>> getFixturesByGame(
      String tournamentId, String game) {
    return _fixtures(tournamentId)
        .where('game', isEqualTo: game)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        final byDay = a.matchDay.compareTo(b.matchDay);
        if (byDay != 0) return byDay;
        return a.timeSlot.index.compareTo(b.timeSlot.index);
      });
      return list;
    });
  }

  Stream<List<TournamentPoints>> getPointsTable(String tournamentId) {
    return _points(tournamentId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentPoints.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.rank.compareTo(b.rank));
      return list;
    });
  }
// ---------------------------------------------------------------------
  // FIXTURE RESULT ENTRY
  // ---------------------------------------------------------------------

  /// Saves the admin's result for a fixture and refreshes the standings.
  /// Returns an error message when the input is invalid (null = success).
  Future<String?> enterFixtureResult({
    required String tournamentId,
    required String fixtureId,
    required String rawInput,
  }) async {
    final result = TournamentResultParser.parse(rawInput);
    if (result == null) return 'Enter A, B or Draw';

    final points = TournamentResultParser.pointsFor(result);
    await _fixtures(tournamentId).doc(fixtureId).update({
      'result': result.name,
      'homePts': points.homePts,
      'awayPts': points.awayPts,
    });
    await _recalculatePoints(tournamentId);
    return null;
  }

  Future<void> clearFixtureResult({
    required String tournamentId,
    required String fixtureId,
  }) async {
    await _fixtures(tournamentId).doc(fixtureId).update({
      'result': null,
      'homePts': 0,
      'awayPts': 0,
    });
    await _recalculatePoints(tournamentId);
  }

  /// Re-seeds the verified workbook fixtures and rebuilds the points table.
  Future<void> reseedFixtures(String tournamentId) async {
    await _seedVerifiedFixtures(tournamentId);
    await _recalculatePoints(tournamentId);
  }

  Future<void> _seedVerifiedFixtures(String tournamentId) async {
    final fixtures = InterClanFixtureSeed.build(tournamentId);
    final batch = _db.batch();
    final col = _fixtures(tournamentId);
    for (final fixture in fixtures) {
      batch.set(col.doc(fixture.id), fixture.toMap());
    }
    await batch.commit();
  }

  Future<void> _initializePoints(
      String tournamentId, List<String> tribes) async {
    final batch = _db.batch();
    final col = _points(tournamentId);
    for (final tribe in tribes) {
      batch.set(col.doc(tribe), {
        'tournamentId': tournamentId,
        'tribe': tribe,
        'course': tribe,
        'clan': tribe,
        'gamePoints': {for (final g in InterClanGames2026.games) g: 0},
        'spiritPoints': 0,
        'totalPoints': 0,
        'rank': 0,
      });
    }
    await batch.commit();
  }

  Future<void> _initializeTribeRegistrations(String tournamentId) async {
    final batch = _db.batch();
    final col = _tribeRegistrations(tournamentId);
    for (final tribe in InterClanGames2026.clans) {
      batch.set(col.doc(tribe), {
        'tournamentId': tournamentId,
        'tribe': tribe,
        'isRegistered': false,
      });
    }
    await batch.commit();
  }

  Future<void> _recalculatePoints(String tournamentId) async {
    final tournamentDoc = await _tournaments.doc(tournamentId).get();
    if (!tournamentDoc.exists) return;
    final tournament =
        TournamentModel.fromMap(tournamentDoc.data()!, tournamentId);

    final fixturesSnapshot = await _fixtures(tournamentId).get();
    final pointsMap = <String, Map<String, int>>{};
    for (final tribe in tournament.tribes) {
      pointsMap[tribe] = {for (final g in tournament.games) g: 0};
    }

    for (final doc in fixturesSnapshot.docs) {
      final fixture = TournamentFixture.fromMap(doc.data(), doc.id);
      if (fixture.result == null ||
          (fixture.homePts == 0 && fixture.awayPts == 0)) {
        continue;
      }
      final homeEntry = pointsMap[fixture.homeClan];
      final awayEntry = pointsMap[fixture.awayClan];
      if (homeEntry != null) {
        homeEntry[fixture.game] =
            (homeEntry[fixture.game] ?? 0) + fixture.homePts;
      }
      if (awayEntry != null) {
        awayEntry[fixture.game] =
            (awayEntry[fixture.game] ?? 0) + fixture.awayPts;
      }
    }

    final ranked = tournament.tribes.map((tribe) {
      final total = pointsMap[tribe]!.values.fold(0, (a, b) => a + b);
      return MapEntry(tribe, total);
    }).toList();
    ranked.sort((a, b) => b.value.compareTo(a.value));

    final batch = _db.batch();
    for (int i = 0; i < ranked.length; i++) {
      final tribe = ranked[i].key;
      batch.update(_points(tournamentId).doc(tribe), {
        'gamePoints': pointsMap[tribe],
        'totalPoints': ranked[i].value,
        'rank': i + 1,
      });
    }
    await batch.commit();
  }
// ---------------------------------------------------------------------
  // SQUAD (STUDENT) REGISTRATION
  // ---------------------------------------------------------------------

  Future<bool> registerStudent({
    required String tournamentId,
    required String tribe,
    required String game,
    required String studentName,
    required String studentNumber,
  }) async {
    if (_currentUserId == null) return false;

    final existing = await _squads(tournamentId)
        .where('studentId', isEqualTo: _currentUserId)
        .where('course', isEqualTo: tribe)
        .where('game', isEqualTo: game)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return false;

    await _squads(tournamentId).add({
      'tournamentId': tournamentId,
      'tribe': tribe,
      'course': tribe,
      'clan': tribe,
      'game': game,
      'studentId': _currentUserId,
      'studentName': studentName,
      'studentNumber': studentNumber,
      'registeredAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<List<TournamentSquad>> getStudentRegistrations(
      String tournamentId) async {
    if (_currentUserId == null) return [];
    final snapshot = await _squads(tournamentId)
        .where('studentId', isEqualTo: _currentUserId)
        .get();
    return snapshot.docs
        .map((doc) => TournamentSquad.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<TournamentSquad>> getSquadsByGame(
      String tournamentId, String game) async {
    final snapshot = await _squads(tournamentId)
        .where('game', isEqualTo: game)
        .orderBy('registeredAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TournamentSquad.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ---------------------------------------------------------------------
  // TRIBE REGISTRATION (workbook Registration sheet, admin-managed)
  // ---------------------------------------------------------------------

  Stream<List<TribeRegistration>> getTribeRegistrations(
      String tournamentId) {
    return _tribeRegistrations(tournamentId).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TribeRegistration.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateTribeRegistration(
      String tournamentId, TribeRegistration registration) async {
    await _tribeRegistrations(tournamentId)
        .doc(registration.id)
        .set(registration.toMap());
  }

  // ---------------------------------------------------------------------
  // IN-APP NOTIFICATIONS
  // ---------------------------------------------------------------------

  Future<void> _notifyAllStudents(String title, String message) async {
    final usersSnapshot = await _db.collection('users').get();
    final batch = _db.batch();
    for (final userDoc in usersSnapshot.docs) {
      batch.set(_db.collection('notifications').doc(), {
        'userId': userDoc.id,
        'title': title,
        'message': message,
        'type': 'tournament',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': null,
      });
    }
    await batch.commit();
  }

  Future<void> notifyMatchDay(
      String tournamentId, String game, DateTime date) async {
    final usersSnapshot = await _db.collection('users').get();
    final batch = _db.batch();
    final dateLabel = '${date.day}/${date.month}';
    for (final userDoc in usersSnapshot.docs) {
      batch.set(_db.collection('notifications').doc(), {
        'userId': userDoc.id,
        'title': 'Match Day Reminder',
        'message': '$game matches are happening today ($dateLabel)',
        'type': 'tournament',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': tournamentId,
      });
    }
    await batch.commit();
  }
}