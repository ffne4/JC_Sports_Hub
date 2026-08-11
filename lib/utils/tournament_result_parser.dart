import '../models/tournament_model.dart';

/// Parses admin result input into exactly one of three outcomes.
/// Tolerant of case/whitespace; returns null for invalid input.
class TournamentResultParser {
  TournamentResultParser._();

  static MatchResult? parse(String input) {
    final normalized = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;

    const teamAWin = {
      'a',
      'team a',
      'team a win',
      'home',
      'home win',
    };
    const teamBWin = {
      'b',
      'team b',
      'team b win',
      'away',
      'away win',
    };
    const draw = {
      'draw',
      'd',
      'tie',
      'x',
    };

    if (teamAWin.contains(normalized)) return MatchResult.teamAWin;
    if (teamBWin.contains(normalized)) return MatchResult.teamBWin;
    if (draw.contains(normalized)) return MatchResult.draw;
    return null;
  }

  static String label(MatchResult result) {
    switch (result) {
      case MatchResult.teamAWin:
        return 'Team A Win';
      case MatchResult.teamBWin:
        return 'Team B Win';
      case MatchResult.draw:
        return 'Draw';
    }
  }

  static ({int homePts, int awayPts}) pointsFor(MatchResult result) {
    switch (result) {
      case MatchResult.teamAWin:
        return (homePts: 3, awayPts: 0);
      case MatchResult.teamBWin:
        return (homePts: 0, awayPts: 3);
      case MatchResult.draw:
        return (homePts: 1, awayPts: 1);
    }
  }
}
