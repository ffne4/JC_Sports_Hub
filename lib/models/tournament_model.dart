import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentStatus { upcoming, ongoing, completed }

enum MatchStage { round1, round2, round3, round4, round5, groupA, groupB, semiFinal1, semiFinal2, championship }


class TournamentModel {
  final String id;
  final String name;
  final String season;
  final TournamentStatus status;
  final DateTime registrationOpen;
  final DateTime registrationClose;
  final DateTime leagueStart;
  final DateTime leagueEnd;
  final DateTime? finalsStart;
  final DateTime? finalsEnd;
  final DateTime? closingCeremony;
  final List<String> courses;
  final List<String> games;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  TournamentModel({
    required this.id,
    required this.name,
    required this.season,
    required this.status,
    required this.registrationOpen,
    required this.registrationClose,
    required this.leagueStart,
    required this.leagueEnd,
    this.finalsStart,
    this.finalsEnd,
    this.closingCeremony,
    required this.courses,
    required this.games,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  factory TournamentModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    TournamentStatus parseStatus(String? value) {
      switch (value) {
        case 'ongoing':
          return TournamentStatus.ongoing;
        case 'completed':
          return TournamentStatus.completed;
        case 'upcoming':
        default:
          return TournamentStatus.upcoming;
      }
    }

    return TournamentModel(
      id: docId,
      name: map['name'] ?? '',
      season: map['season'] ?? '',
      status: parseStatus(map['status']),
      registrationOpen: parseDate(map['registrationOpen']),
      registrationClose: parseDate(map['registrationClose']),
      leagueStart: parseDate(map['leagueStart']),
      leagueEnd: parseDate(map['leagueEnd']),
      finalsStart: map['finalsStart'] != null ? parseDate(map['finalsStart']) : null,
      finalsEnd: map['finalsEnd'] != null ? parseDate(map['finalsEnd']) : null,
      closingCeremony: map['closingCeremony'] != null ? parseDate(map['closingCeremony']) : null,
      courses: List<String>.from(map['courses'] ?? const ['Electrical','Civil','Business','Arts','BIST','Computer Science']),
      games: List<String>.from(map['games'] ?? const ['Football','Netball','Volleyball','Chess','Scrabble','Ludo','Matatu/Cards']),
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'season': season,
      'status': status.name,
      'registrationOpen': Timestamp.fromDate(registrationOpen),
      'registrationClose': Timestamp.fromDate(registrationClose),
      'leagueStart': Timestamp.fromDate(leagueStart),
      'leagueEnd': Timestamp.fromDate(leagueEnd),
      'finalsStart': finalsStart != null ? Timestamp.fromDate(finalsStart!) : null,
      'finalsEnd': finalsEnd != null ? Timestamp.fromDate(finalsEnd!) : null,
      'closingCeremony': closingCeremony != null ? Timestamp.fromDate(closingCeremony!) : null,
      'courses': courses,
      'games': games,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}

class TournamentSquad {
  final String id;
  final String tournamentId;
  final String course;
  final String game;
  final String studentId;
  final String studentName;
  final String studentNumber;
  final DateTime registeredAt;

  TournamentSquad({
    required this.id,
    required this.tournamentId,
    required this.course,
    required this.game,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.registeredAt,
  });

  factory TournamentSquad.fromMap(Map<String, dynamic> map, String docId) {
    return TournamentSquad(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      course: map['course'] ?? '',
      game: map['game'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentNumber: map['studentNumber'] ?? '',
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'course': course,
      'game': game,
      'studentId': studentId,
      'studentName': studentName,
      'studentNumber': studentNumber,
      'registeredAt': FieldValue.serverTimestamp(),
    };
  }
}

class TournamentFixture {
  final String id;
  final String tournamentId;
  final String game;
  final int round;
  final String stage;
  final DateTime date;
  final String homeCourse;
  final String awayCourse;
  final String? result;
  final int homePts;
  final int awayPts;
  final String? notes;

  TournamentFixture({
    required this.id,
    required this.tournamentId,
    required this.game,
    required this.round,
    required this.stage,
    required this.date,
    required this.homeCourse,
    required this.awayCourse,
    this.result,
    this.homePts = 0,
    this.awayPts = 0,
    this.notes,
  });

  factory TournamentFixture.fromMap(Map<String, dynamic> map, String docId) {
    return TournamentFixture(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      game: map['game'] ?? '',
      round: map['round'] ?? 0,
      stage: map['stage'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      homeCourse: map['homeCourse'] ?? '',
      awayCourse: map['awayCourse'] ?? '',
      result: map['result'],
      homePts: map['homePts'] ?? 0,
      awayPts: map['awayPts'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'game': game,
      'round': round,
      'stage': stage,
      'date': Timestamp.fromDate(date),
      'homeCourse': homeCourse,
      'awayCourse': awayCourse,
      'result': result,
      'homePts': homePts,
      'awayPts': awayPts,
      'notes': notes,
    };
  }
}

class TournamentPoints {
  final String id;
  final String tournamentId;
  final String course;
  final Map<String, int> gamePoints;
  final int spiritPoints;
  final int totalPoints;
  final int rank;

  TournamentPoints({
    required this.id,
    required this.tournamentId,
    required this.course,
    required this.gamePoints,
    required this.spiritPoints,
    required this.totalPoints,
    required this.rank,
  });

  factory TournamentPoints.fromMap(Map<String, dynamic> map, String docId) {
    return TournamentPoints(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      course: map['course'] ?? '',
      gamePoints: Map<String, int>.from(map['gamePoints'] ?? const {}),
      spiritPoints: map['spiritPoints'] ?? 0,
      totalPoints: map['totalPoints'] ?? 0,
      rank: map['rank'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'course': course,
      'gamePoints': gamePoints,
      'spiritPoints': spiritPoints,
      'totalPoints': totalPoints,
      'rank': rank,
    };
  }
}
