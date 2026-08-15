import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tournament_model.dart';

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');

  Future<String> createTournament(TournamentModel tournament) async {
    final docRef = await _tournaments.add(tournament.toMap());
    await _autoGenerateFixtures(docRef.id, tournament);
    await _initializePoints(docRef.id, tournament);
    await _notifyAllStudents('New Tournament', ' has been published');
    return docRef.id;
  }

  Stream<List<TournamentModel>> getActiveTournaments() {
    return _tournaments
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TournamentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<TournamentModel?> getCurrentTournament() {
    return _tournaments
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return TournamentModel.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  Future<void> updateTournamentStatus(
      String tournamentId, TournamentStatus status) async {
    await _tournaments.doc(tournamentId).update({
      'status': status.name,
      'isActive': status != TournamentStatus.completed,
    });
  }

  CollectionReference<Map<String, dynamic>> _squads(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('squads');

  Future<bool> registerStudent({
    required String tournamentId,
    required String course,
    required String game,
    required String studentName,
    required String studentNumber,
  }) async {
    if (_currentUserId == null) return false;

    final existing = await _squads(tournamentId)
        .where('studentId', isEqualTo: _currentUserId)
        .where('course', isEqualTo: course)
        .where('game', isEqualTo: game)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return false;

    await _squads(tournamentId).add({
      'tournamentId': tournamentId,
      'course': course,
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

  Future<void> _autoGenerateFixtures(
      String tournamentId, TournamentModel tournament) async {
    final fixturesCollection =
        _tournaments.doc(tournamentId).collection('fixtures');
    final batch = _db.batch();

    for (final game in tournament.games) {
      if (game == 'Chess' ||
          game == 'Scrabble' ||
          game == 'Ludo' ||
          game == 'Matatu/Cards') {
        await _generateKnockoutFixtures(
            batch, fixturesCollection, tournamentId, game, tournament.courses);
      } else {
        await _generateLeagueFixtures(
            batch, fixturesCollection, tournamentId, game, tournament.courses);
      }
    }

    await batch.commit();
  }

  Future<void> _generateLeagueFixtures(
    WriteBatch batch,
    CollectionReference<Map<String, dynamic>> fixturesCollection,
    String tournamentId,
    String game,
    List<String> courses,
  ) async {
    final dates = _getMatchDates();
    int fixtureIndex = 0;
    final matchesPerRound = courses.length - 1;

    for (final home in courses) {
      for (final away in courses) {
        if (home == away) continue;
        final docRef = fixturesCollection.doc();
        final roundNumber = (fixtureIndex ~/ matchesPerRound) + 1;
        batch.set(
            docRef,
            TournamentFixture(
              id: docRef.id,
              tournamentId: tournamentId,
              game: game,
              round: roundNumber,
              stage: 'Round $roundNumber',
              date: dates[fixtureIndex % dates.length],
              homeCourse: home,
              awayCourse: away,
            ).toMap());
        fixtureIndex++;
      }
    }
  }

  Future<void> _generateKnockoutFixtures(
    WriteBatch batch,
    CollectionReference<Map<String, dynamic>> fixturesCollection,
    String tournamentId,
    String game,
    List<String> courses,
  ) async {
    final shuffled = List<String>.from(courses)..shuffle();
    final groupA = shuffled.take(3).toList();
    final groupB = shuffled.skip(3).take(3).toList();
    final dates = _getKnockoutDates();
    int fixtureIndex = 0;

    for (final group in [groupA, groupB]) {
      final groupLabel = group == groupA ? 'Group A' : 'Group B';
      for (int i = 0; i < group.length; i++) {
        for (int j = i + 1; j < group.length; j++) {
          final docRef = fixturesCollection.doc();
          batch.set(
              docRef,
              TournamentFixture(
                id: docRef.id,
                tournamentId: tournamentId,
                game: game,
                round: fixtureIndex + 1,
                stage: groupLabel,
                date: dates[fixtureIndex % dates.length],
                homeCourse: group[i],
                awayCourse: group[j],
              ).toMap());
          fixtureIndex++;
        }
      }
    }

    final semi1 = fixturesCollection.doc();
    batch.set(
        semi1,
        TournamentFixture(
          id: semi1.id,
          tournamentId: tournamentId,
          game: game,
          round: fixtureIndex + 1,
          stage: 'Semi-Final 1',
          date: dates[fixtureIndex % dates.length],
          homeCourse: 'Group A Winner',
          awayCourse: 'Group B Runner-up',
        ).toMap());
    fixtureIndex++;

    final semi2 = fixturesCollection.doc();
    batch.set(
        semi2,
        TournamentFixture(
          id: semi2.id,
          tournamentId: tournamentId,
          game: game,
          round: fixtureIndex + 1,
          stage: 'Semi-Final 2',
          date: dates[fixtureIndex % dates.length],
          homeCourse: 'Group B Winner',
          awayCourse: 'Group A Runner-up',
        ).toMap());
    fixtureIndex++;

    final finalMatch = fixturesCollection.doc();
    batch.set(
        finalMatch,
        TournamentFixture(
          id: finalMatch.id,
          tournamentId: tournamentId,
          game: game,
          round: fixtureIndex + 1,
          stage: 'Final',
          date: dates[fixtureIndex % dates.length],
          homeCourse: 'Semi-Final 1 Winner',
          awayCourse: 'Semi-Final 2 Winner',
        ).toMap());
  }

  List<DateTime> _getMatchDates() {
    final dates = <DateTime>[];
    var current = DateTime(2026, 8, 19);
    final end = DateTime(2026, 10, 30);
    while (current.isBefore(end)) {
      if (current.weekday == DateTime.wednesday ||
          current.weekday == DateTime.friday) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  List<DateTime> _getKnockoutDates() {
    return [
      DateTime(2026, 8, 19),
      DateTime(2026, 8, 26),
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 16),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 14),
      DateTime(2026, 10, 23),
      DateTime(2026, 10, 28),
    ];
  }

  CollectionReference<Map<String, dynamic>> _fixtures(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('fixtures');

  Stream<List<TournamentFixture>> getFixturesByGame(
      String tournamentId, String game) {
    return _fixtures(tournamentId).orderBy('date').snapshots().map((snapshot) {
      final fixtures = snapshot.docs
          .map((doc) => TournamentFixture.fromMap(doc.data(), doc.id));
      return fixtures.where((fixture) => fixture.game == game).toList();
    });
  }

  Future<void> updateFixtureResult({
    required String tournamentId,
    required String fixtureId,
    required String result,
    required int homePts,
    required int awayPts,
  }) async {
    await _fixtures(tournamentId).doc(fixtureId).update({
      'result': result,
      'homePts': homePts,
      'awayPts': awayPts,
    });
    await _recalculatePoints(tournamentId);
  }

  CollectionReference<Map<String, dynamic>> _points(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('points');

  Future<void> _initializePoints(
      String tournamentId, TournamentModel tournament) async {
    final batch = _db.batch();
    for (final course in tournament.courses) {
      final docRef = _points(tournamentId).doc(course);
      batch.set(
          docRef,
          TournamentPoints(
            id: docRef.id,
            tournamentId: tournamentId,
            course: course,
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
    for (final course in tournament.courses) {
      pointsMap[course] = {for (final g in tournament.games) g: 0};
    }

    for (final doc in fixturesSnapshot.docs) {
      final fixture = TournamentFixture.fromMap(doc.data(), doc.id);
      if (fixture.result == null ||
          fixture.homePts == 0 && fixture.awayPts == 0) {
        continue;
      }

      final homeEntry = pointsMap[fixture.homeCourse];
      final awayEntry = pointsMap[fixture.awayCourse];

      if (homeEntry != null) {
        homeEntry[fixture.game] =
            (homeEntry[fixture.game] ?? 0) + fixture.homePts;
      }
      if (awayEntry != null) {
        awayEntry[fixture.game] =
            (awayEntry[fixture.game] ?? 0) + fixture.awayPts;
      }
    }

    final ranked = tournament.courses.map((course) {
      final total = pointsMap[course]!.values.fold(0, (a, b) => a + b);
      return MapEntry(course, total);
    }).toList();
    ranked.sort((a, b) => b.value.compareTo(a.value));

    final batch = _db.batch();
    for (int i = 0; i < ranked.length; i++) {
      final course = ranked[i].key;
      final total = ranked[i].value;
      final pointsDoc = _points(tournamentId).doc(course);
      batch.update(pointsDoc, {
        'gamePoints': pointsMap[course],
        'totalPoints': total,
        'rank': i + 1,
      });
    }
    await batch.commit();
  }

  Stream<List<TournamentPoints>> getPointsTable(String tournamentId) {
    return _points(tournamentId).orderBy('rank').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TournamentPoints.fromMap(doc.data(), doc.id))
            .toList());
  }

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
    const dateStr = '//';
    for (final userDoc in usersSnapshot.docs) {
      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': userDoc.id,
        'title': 'Match Day Reminder',
        'message': ' matches are happening today ()',
        'type': 'tournament',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': tournamentId,
      });
    }
    await batch.commit();
  }
}
