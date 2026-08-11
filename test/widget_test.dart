// Basic, Firebase-independent smoke test for the JC Sports Hub app.
// The app's real entrypoint boots through Firebase (not available in the
// widget-test environment), so this exercises pure widget semantics instead of
// the counter example that used to ship with Flutter templates.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jc_sports_hub/data/inter_clan_games_constants.dart';
import 'package:jc_sports_hub/models/tournament_model.dart';
import 'package:jc_sports_hub/utils/tournament_result_parser.dart';

void main() {
  testWidgets('renders a simple app and responds to taps', (tester) async {
    var counter = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => counter++,
              child: const Text('Tap me'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tap me'), findsOneWidget);
    await tester.tap(find.text('Tap me'));
    expect(counter, 1);
  });

  test('season constants are fully populated (no empty game/clan names)', () {
    expect(InterClanGames2026.clans, isNotEmpty);
    expect(InterClanGames2026.games, isNotEmpty);
    expect(InterClanGames2026.games.where((g) => g.isEmpty), isEmpty);
    expect(InterClanGames2026.clans.where((c) => c.isEmpty), isEmpty);
    expect(InterClanGames2026.games, hasLength(7));
    expect(InterClanGames2026.matchDays, hasLength(6));
  });

  test('result parser labels are consistent with points', () {
    expect(
      TournamentResultParser.label(MatchResult.teamAWin),
      'Team A Win',
    );
    expect(TournamentResultParser.pointsFor(MatchResult.draw),
        (homePts: 1, awayPts: 1));
  });
}

