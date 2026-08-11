import 'package:flutter_test/flutter_test.dart';
import 'package:jc_sports_hub/data/inter_clan_fixture_seed.dart';
import 'package:jc_sports_hub/data/inter_clan_games_constants.dart';
import 'package:jc_sports_hub/models/tournament_model.dart';
import 'package:jc_sports_hub/utils/tournament_fairness_check.dart';
import 'package:jc_sports_hub/utils/tournament_result_parser.dart';

void main() {
  group('Inter-Clan Games 2026 verified seed', () {
    final fixtures = InterClanFixtureSeed.build('test-tournament');

    test('contains exactly the six workbook match-days and 84 fixtures', () {
      expect(fixtures, hasLength(84));
      expect(
        fixtures.map((f) => f.date).toSet(),
        equals(InterClanGames2026.matchDays.toSet()),
      );
    });

    test('keeps every pair meeting twice per game and team-sport slots 3-3', () {
      final report = TournamentFairnessCheck.analyze(fixtures);
      expect(report.allValid, isTrue);
      expect(report.pairMeetings, hasLength(42));
      expect(report.slotBalances, hasLength(12));
    });
  });

  group('result input', () {
    test('accepts only the three intended outcomes, ignoring case and whitespace', () {
      expect(TournamentResultParser.parse(' A '), MatchResult.teamAWin);
      expect(TournamentResultParser.parse('b'), MatchResult.teamBWin);
      expect(TournamentResultParser.parse('  DRAW  '), MatchResult.draw);
      expect(TournamentResultParser.parse('winner'), isNull);
      expect(TournamentResultParser.parse(''), isNull);
    });

    test('assigns win, draw and loss points correctly', () {
      expect(TournamentResultParser.pointsFor(MatchResult.teamAWin),
          (homePts: 3, awayPts: 0));
      expect(TournamentResultParser.pointsFor(MatchResult.teamBWin),
          (homePts: 0, awayPts: 3));
      expect(TournamentResultParser.pointsFor(MatchResult.draw),
          (homePts: 1, awayPts: 1));
    });
  });
}
