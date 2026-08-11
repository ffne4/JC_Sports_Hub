/// Verified season configuration for Inter-Tribe Games 2026.
/// Source: Inter_Clan_Games_2026 (10).xlsx — Read Me sheet.
class InterClanGames2026 {
  InterClanGames2026._();

  static const String tournamentName =
      'MAK Jinja Campus Inter-Tribe Games 2026';
  static const String season = '2026/2027';

  // DateTime() is not a const constructor, so these season dates are `final`
  // (still immutable, still a single named source of truth — never magic strings).
  static final DateTime registrationOpen = DateTime(2026, 8, 10);
  static final DateTime registrationClose = DateTime(2026, 8, 17);

  /// Six verified match-days (Wed/Fri only).
  static final List<DateTime> matchDays = [
    DateTime(2026, 8, 19),
    DateTime(2026, 9, 4),
    DateTime(2026, 9, 23),
    DateTime(2026, 10, 7),
    DateTime(2026, 10, 23),
    DateTime(2026, 11, 11),
  ];

  static final DateTime leagueStart = DateTime(2026, 8, 19);
  static final DateTime leagueEnd = DateTime(2026, 11, 11);
  static final DateTime grandFinale = DateTime(2026, 11, 11);

  static const List<String> clans = [
    'Basoga Nsete',
    'Nkobazambogo',
    'Muwesa',
    'Northerners',
  ];

  static const List<String> teamSports = [
    'Football',
    'Netball',
    'Volleyball',
  ];

  static const List<String> mindGames = [
    'Chess',
    'Scrabble',
    'Ludo',
    'Matatu',
  ];

  static const List<String> games = [
    ...teamSports,
    ...mindGames,
  ];

  static const int pointsWin = 3;
  static const int pointsDraw = 1;
  static const int pointsLoss = 0;

  /// Expected meetings between any two tribes in one game across the season.
  static const int expectedMeetingsPerPairPerGame = 2;

  /// Expected 4 PM / 5 PM slot split per tribe per team sport.
  static const int expectedSlotBalance = 3;
}
