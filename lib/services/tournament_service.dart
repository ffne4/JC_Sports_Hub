import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/inter_clan_fixture_seed.dart';
import '../data/inter_clan_games_constants.dart';
import '../models/tournament_model.dart';
import '../utils/tournament_result_parser.dart';

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');

  /// Creates the verified Inter-Tribe Games 2026 tournament with exact spreadsheet fixtures.
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
    await _initializePoints(docRef.id, tournament);
    await _initializeTribeRegistrations(docRef.id);
    await _notifyAllStudents(
      'New Tournament',
      '${tournament.name} has been published',
    );
    return docRef.id;
  }

  Stream<List<TournamentModel>> getActiveTournaments() {
    return _tournaments
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final tournaments = snapshot.docs
          .map((doc) => TournamentModel.fromMap(doc.data(), doc.id))
          .toList();
      tournaments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tournaments;
    });
  }

  Stream<TournamentModel?> getCurrentTournament() {
    return _tournaments
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return TournamentModel.fromMap(docs.first.data(), docs.first.id);
    });
  }

  Future<void> updateTournamentStatus(
      String tournamentId, TournamentStatus status) async {
    await _tournaments.doc(tournamentId).update({
      'status': status.name,
      'isActive': status != TournamentStatus.completed,
    });
  }

  Future<void> deleteTournament(String tournamentId) async {
    final doc = _tournaments.doc(tournamentId);
    final subcollections = await doc.collection('fixtures').get();
    final batch = _db.batch();
    for (final doc in subcollections.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await _tournaments.doc(tournamentId).delete();
  }

  Future<void> reseedFixtures(String tournamentId) async {
    final fixtures = _fixtures(tournamentId);
    final existing = await fixtures.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    final seeded = InterClanFixtureSeed.build(tournamentId);
    final writeBatch = _db.batch();
    for (final fixture in seeded) {
      final ref = fixtures.doc();
      writeBatch.set(ref, fixture.toMap());
    }
    await writeBatch.commit();
    await _recalculatePoints(tournamentId);
  }

  // ── Squads (student-level registration) ──────────────────────────────────

  CollectionReference<Map<String, dynamic>> _squads(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('squads');

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
        .where('tribe', isEqualTo: tribe)
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

  // ── Tribe registrations (spreadsheet Registration sheet) ──────────────────

  CollectionReference<Map<String, dynamic>> _tribeRegistrations(
          String tournamentId) =>
      _tournaments.doc(tournamentId).collection('tribeRegistrations');

  Future<void> _initializeTribeRegistrations(String tournamentId) async {
    final batch = _db.batch();
    for (final tribe in InterClanGames2026.clans) {
      final docRef = _tribeRegistrations(tournamentId).doc(tribe);
      batch.set(
        docRef,
        TribeRegistration(
          id: tribe,
          tournamentId: tournamentId,
          tribe: tribe,
        ).toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Stream<List<TribeRegistration>> getTribeRegistrations(String tournamentId) {
    return _tribeRegistrations(tournamentId).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TribeRegistration.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => a.tribe.compareTo(b.tribe)));
  }

  Future<void> updateTribeRegistration(
      String tournamentId, TribeRegistration registration) async {
    await _tribeRegistrations(tournamentId)
        .doc(registration.tribe)
        .set(registration.toMap(), SetOptions(merge: true));
  }

  // ── Verified fixture seed (NO randomizer) ────────────────────────────────

  Future<void> _seedVerifiedFixtures(String tournamentId) async {
    final fixtures = InterClanFixtureSeed.build(tournamentId);
    final batch = _db.batch();
    final fixturesCollection =
        _tournaments.doc(tournamentId).collection('fixtures');

    for (final fixture in fixtures) {
      batch.set(fixturesCollection.doc(fixture.id), fixture.toMap());
    }
    await batch.commit();
  }

  /// Re-seed fixtures for an existing tournament (admin only).
  Future<void> reseedVerifiedFixtures(String tournamentId) async {
    final fixturesCollection =
        _tournaments.doc(tournamentId).collection('fixtures');
    final existing = await fixturesCollection.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await _seedVerifiedFixtures(tournamentId);
  }

  CollectionReference<Map<String, dynamic>> _fixtures(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('fixtures');

  Stream<List<TournamentFixture>> getAllFixtures(String tournamentId) {
    return _fixtures(tournamentId).snapshots().map((snapshot) {
      final fixtures = snapshot.docs
          .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
          .toList();
      fixtures.sort((a, b) {
        final dayCompare = a.matchDay.compareTo(b.matchDay);
        if (dayCompare != 0) return dayCompare;
        final gameCompare = a.game.compareTo(b.game);
        if (gameCompare != 0) return gameCompare;
        return a.timeSlot.index.compareTo(b.timeSlot.index);
      });
      return fixtures;
    });
  }

  Stream<List<TournamentFixture>> getFixturesByGame(
      String tournamentId, String game) {
    return _fixtures(tournamentId)
        .where('game', isEqualTo: game)
        .snapshots()
        .map((snapshot) {
      final fixtures = snapshot.docs
          .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
          .toList();
      fixtures.sort((a, b) {
        final dayCompare = a.matchDay.compareTo(b.matchDay);
        if (dayCompare != 0) return dayCompare;
        return a.timeSlot.index.compareTo(b.timeSlot.index);
      });
      return fixtures;
    });
  }

  Stream<List<TournamentFixture>> getFixturesByMatchDay(
      String tournamentId, int matchDay) {
    return _fixtures(tournamentId)
        .where('matchDay', isEqualTo: matchDay)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Enter a result using raw admin input (A / B / Draw).
  /// Returns null on success, or an error message if input is invalid.
  Future<String?> enterFixtureResult({
    required String tournamentId,
    required String fixtureId,
    required String rawInput,
  }) async {
    final parsed = TournamentResultParser.parse(rawInput);
    if (parsed == null) {
      return 'Invalid result. Enter A (Team A win), B (Team B win), or Draw.';
    }

    final pts = TournamentResultParser.pointsFor(parsed);
    final fixtureRef = _fixtures(tournamentId).doc(fixtureId);
    final resultRef = _tournaments
        .doc(tournamentId)
        .collection('results')
        .doc(fixtureId);
    final result = FixtureResult(
      fixtureId: fixtureId,
      winner: parsed,
      teamAPoints: pts.homePts,
      teamBPoints: pts.awayPts,
    );
    final batch = _db.batch();
    batch.update(fixtureRef, {
      'result': parsed.name,
      'homePts': pts.homePts,
      'awayPts': pts.awayPts,
    });
    batch.set(resultRef, result.toMap());
    await batch.commit();
    await _recalculatePoints(tournamentId);
    return null;
  }

  Future<void> clearFixtureResult({
    required String tournamentId,
    required String fixtureId,
  }) async {
    final batch = _db.batch();
    batch.update(_fixtures(tournamentId).doc(fixtureId), {
      'result': null,
      'homePts': 0,
      'awayPts': 0,
    });
    batch.delete(
      _tournaments.doc(tournamentId).collection('results').doc(fixtureId),
    );
    await batch.commit();
    await _recalculatePoints(tournamentId);
  }

  // ── Points table ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _points(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('points');

  Future<void> _initializePoints(
      String tournamentId, TournamentModel tournament) async {
    final batch = _db.batch();
    for (final tribe in tournament.tribes) {
      final docRef = _points(tournamentId).doc(tribe);
      batch.set(
          docRef,
          TournamentPoints(
            id: docRef.id,
            tournamentId: tournamentId,
            tribe: tribe,
            gamePoints: {for (final g in tournament.games) g: 0},
            spiritPoints: 0,
            totalPoints: 0,
            rank: 0,
          ).toMap());
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
      if (fixture.result == null) continue;

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
      final total = ranked[i].value;
      final pointsDoc = _points(tournamentId).doc(tribe);
      batch.set(
        pointsDoc,
        {
          'gamePoints': pointsMap[tribe],
          'totalPoints': total,
          'rank': i + 1,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Stream<List<TournamentPoints>> getPointsTable(String tournamentId) {
    return _points(tournamentId).orderBy('rank').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TournamentPoints.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<void> _notifyAllStudents(String title, String message) async {
    final usersSnapshot = await _db.collection('users').get();
    final batch = _db.batch();
    for (final userDoc in usersSnapshot.docs) {
      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
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
    final dateStr = '${date.day}/${date.month}/${date.year}';
    for (final userDoc in usersSnapshot.docs) {
      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': userDoc.id,
        'title': 'Match Day Reminder',
        'message': '$game matches are happening today ($dateStr)',
        'type': 'tournament',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': tournamentId,
      });
    }
    await batch.commit();
  }
}
