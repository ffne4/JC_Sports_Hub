import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inter_clan_games_constants.dart';

enum TournamentStatus { upcoming, ongoing, completed }

enum GameCategory { teamSport, mindGame }

enum FixtureTimeSlot { slot1_4pm, slot2_5pm, mind_3pm }

enum MatchResult { teamAWin, teamBWin, draw }

/// A named game in a tournament. Fixtures retain the game name for efficient
/// Firestore queries, while this model preserves its category as domain data.
class TournamentGame {
  final String name;
  final GameCategory category;

  const TournamentGame({required this.name, required this.category});

  Map<String, dynamic> toMap() => {'name': name, 'category': category.name};

  factory TournamentGame.fromMap(Map<String, dynamic> map) => TournamentGame(
        name: map['name'] as String? ?? '',
        category: map['category'] == GameCategory.mindGame.name
            ? GameCategory.mindGame
            : GameCategory.teamSport,
      );
}

/// The scored outcome of one fixture. This is persisted in `results` and the
/// same values are denormalised onto the fixture for live fixture/points views.
class FixtureResult {
  final String fixtureId;
  final MatchResult winner;
  final int teamAPoints;
  final int teamBPoints;

  const FixtureResult({
    required this.fixtureId,
    required this.winner,
    required this.teamAPoints,
    required this.teamBPoints,
  });

  Map<String, dynamic> toMap() => {
        'fixtureId': fixtureId,
        'winner': winner.name,
        'teamAPoints': teamAPoints,
        'teamBPoints': teamBPoints,
      };
}

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
  final List<String> tribes;
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
    required this.tribes,
    required this.games,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  /// Competing tribes (stored as `courses`/`clans` in Firestore for backward compatibility).
  List<String> get clans => tribes;

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
      finalsStart:
          map['finalsStart'] != null ? parseDate(map['finalsStart']) : null,
      finalsEnd: map['finalsEnd'] != null ? parseDate(map['finalsEnd']) : null,
      closingCeremony: map['closingCeremony'] != null
          ? parseDate(map['closingCeremony'])
          : null,
      tribes: List<String>.from(
        map['tribes'] ?? map['courses'] ?? map['clans'] ?? InterClanGames2026.clans,
      ),
      games: List<String>.from(map['games'] ?? InterClanGames2026.games),
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
      'finalsStart':
          finalsStart != null ? Timestamp.fromDate(finalsStart!) : null,
      'finalsEnd': finalsEnd != null ? Timestamp.fromDate(finalsEnd!) : null,
      'closingCeremony': closingCeremony != null
          ? Timestamp.fromDate(closingCeremony!)
          : null,
      'tribes': tribes,
      'courses': tribes,
      'clans': tribes,
      'games': games,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  factory TournamentModel.interClanGames2026({
    required String createdBy,
    TournamentStatus status = TournamentStatus.upcoming,
  }) {
    return TournamentModel(
      id: '',
      name: InterClanGames2026.tournamentName,
      season: InterClanGames2026.season,
      status: status,
      registrationOpen: InterClanGames2026.registrationOpen,
      registrationClose: InterClanGames2026.registrationClose,
      leagueStart: InterClanGames2026.leagueStart,
      leagueEnd: InterClanGames2026.leagueEnd,
      closingCeremony: InterClanGames2026.grandFinale,
      tribes: List<String>.from(InterClanGames2026.clans),
      games: List<String>.from(InterClanGames2026.games),
      createdBy: createdBy,
      createdAt: DateTime.now(),
      isActive: true,
    );
  }
}

class TournamentSquad {
  final String id;
  final String tournamentId;
  final String tribe;
  final String game;
  final String studentId;
  final String studentName;
  final String studentNumber;
  final DateTime registeredAt;

  TournamentSquad({
    required this.id,
    required this.tournamentId,
    required this.tribe,
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
      tribe: map['tribe'] ?? map['course'] ?? map['clan'] ?? '',
      game: map['game'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentNumber: map['studentNumber'] ?? '',
      registeredAt:
          (map['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tribe': tribe,
      'course': tribe,
      'clan': tribe,
      'game': game,
      'studentId': studentId,
      'studentName': studentName,
      'studentNumber': studentNumber,
      'registeredAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Tribe-level registration from the spreadsheet Registration sheet.
class TribeRegistration {
  final String id;
  final String tournamentId;
  final String tribe;
  final String captainName;
  final String phoneContact;
  final String footballSquadNumber;
  final String netballSquadNumber;
  final String volleyballSquadNumber;
  final String chessPlayers;
  final String scrabblePlayers;
  final String ludoPlayers;
  final String matatuPlayers;
  final bool isRegistered;
  final DateTime? registeredAt;

  TribeRegistration({
    required this.id,
    required this.tournamentId,
    required this.tribe,
    this.captainName = '',
    this.phoneContact = '',
    this.footballSquadNumber = '',
    this.netballSquadNumber = '',
    this.volleyballSquadNumber = '',
    this.chessPlayers = '',
    this.scrabblePlayers = '',
    this.ludoPlayers = '',
    this.matatuPlayers = '',
    this.isRegistered = false,
    this.registeredAt,
  });

  factory TribeRegistration.fromMap(Map<String, dynamic> map, String docId) {
    return TribeRegistration(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      tribe: map['tribe'] ?? map['clan'] ?? docId,
      captainName: map['captainName'] ?? '',
      phoneContact: map['phoneContact'] ?? '',
      footballSquadNumber: map['footballSquadNumber'] ?? '',
      netballSquadNumber: map['netballSquadNumber'] ?? '',
      volleyballSquadNumber: map['volleyballSquadNumber'] ?? '',
      chessPlayers: map['chessPlayers'] ?? '',
      scrabblePlayers: map['scrabblePlayers'] ?? '',
      ludoPlayers: map['ludoPlayers'] ?? '',
      matatuPlayers: map['matatuPlayers'] ?? '',
      isRegistered: map['isRegistered'] ?? false,
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tribe': tribe,
      'clan': tribe,
      'captainName': captainName,
      'phoneContact': phoneContact,
      'footballSquadNumber': footballSquadNumber,
      'netballSquadNumber': netballSquadNumber,
      'volleyballSquadNumber': volleyballSquadNumber,
      'chessPlayers': chessPlayers,
      'scrabblePlayers': scrabblePlayers,
      'ludoPlayers': ludoPlayers,
      'matatuPlayers': matatuPlayers,
      'isRegistered': isRegistered,
      'registeredAt': registeredAt != null
          ? Timestamp.fromDate(registeredAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class TournamentFixture {
  final String id;
  final String tournamentId;
  final String game;
  final int matchDay;
  final int round;
  final GameCategory category;
  final FixtureTimeSlot timeSlot;
  final String stage;
  final DateTime date;
  final String homeClan;
  final String awayClan;
  final MatchResult? result;
  final int homePts;
  final int awayPts;
  final String? notes;

  TournamentFixture({
    required this.id,
    required this.tournamentId,
    required this.game,
    required this.matchDay,
    required this.round,
    required this.category,
    required this.timeSlot,
    required this.stage,
    required this.date,
    required this.homeClan,
    required this.awayClan,
    this.result,
    this.homePts = 0,
    this.awayPts = 0,
    this.notes,
  });

  String get homeTribe => homeClan;
  String get awayTribe => awayClan;

  bool get hasResult => result != null;

  factory TournamentFixture.fromMap(Map<String, dynamic> map, String docId) {
    GameCategory parseCategory(String? value) {
      switch (value) {
        case 'mindGame':
          return GameCategory.mindGame;
        case 'teamSport':
        default:
          return GameCategory.teamSport;
      }
    }

    FixtureTimeSlot parseTimeSlot(String? value) {
      switch (value) {
        case 'slot2_5pm':
          return FixtureTimeSlot.slot2_5pm;
        case 'mind_3pm':
          return FixtureTimeSlot.mind_3pm;
        case 'slot1_4pm':
        default:
          return FixtureTimeSlot.slot1_4pm;
      }
    }

    MatchResult? parseResult(String? value) {
      switch (value) {
        case 'teamAWin':
          return MatchResult.teamAWin;
        case 'teamBWin':
          return MatchResult.teamBWin;
        case 'draw':
          return MatchResult.draw;
        default:
          return null;
      }
    }

    return TournamentFixture(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      game: map['game'] ?? '',
      matchDay: map['matchDay'] ?? map['round'] ?? 0,
      round: map['round'] ?? map['matchDay'] ?? 0,
      category: parseCategory(map['category'] as String?),
      timeSlot: parseTimeSlot(map['timeSlot'] as String?),
      stage: map['stage'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      homeClan: map['homeClan'] ?? map['homeCourse'] ?? '',
      awayClan: map['awayClan'] ?? map['awayCourse'] ?? '',
      result: parseResult(map['result'] as String?),
      homePts: map['homePts'] ?? 0,
      awayPts: map['awayPts'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'game': game,
      'matchDay': matchDay,
      'round': round,
      'category': category.name,
      'timeSlot': timeSlot.name,
      'stage': stage,
      'date': Timestamp.fromDate(date),
      'homeClan': homeClan,
      'awayClan': awayClan,
      'homeCourse': homeClan,
      'awayCourse': awayClan,
      'result': result?.name,
      'homePts': homePts,
      'awayPts': awayPts,
      'notes': notes,
    };
  }
}

class TournamentPoints {
  final String id;
  final String tournamentId;
  final String tribe;
  final Map<String, int> gamePoints;
  final int spiritPoints;
  final int totalPoints;
  final int rank;

  TournamentPoints({
    required this.id,
    required this.tournamentId,
    required this.tribe,
    required this.gamePoints,
    required this.spiritPoints,
    required this.totalPoints,
    required this.rank,
  });

  factory TournamentPoints.fromMap(Map<String, dynamic> map, String docId) {
    return TournamentPoints(
      id: docId,
      tournamentId: map['tournamentId'] ?? '',
      tribe: map['tribe'] ?? map['course'] ?? map['clan'] ?? docId,
      gamePoints: Map<String, int>.from(map['gamePoints'] ?? const {}),
      spiritPoints: map['spiritPoints'] ?? 0,
      totalPoints: map['totalPoints'] ?? 0,
      rank: map['rank'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tribe': tribe,
      'course': tribe,
      'clan': tribe,
      'gamePoints': gamePoints,
      'spiritPoints': spiritPoints,
      'totalPoints': totalPoints,
      'rank': rank,
    };
  }
}

GameCategory categoryForGame(String game) {
  return InterClanGames2026.mindGames.contains(game)
      ? GameCategory.mindGame
      : GameCategory.teamSport;
}

String timeSlotLabel(FixtureTimeSlot slot) {
  switch (slot) {
    case FixtureTimeSlot.slot1_4pm:
      return '4:00 PM';
    case FixtureTimeSlot.slot2_5pm:
      return '5:00 PM';
    case FixtureTimeSlot.mind_3pm:
      return '3:00 PM';
  }
}
