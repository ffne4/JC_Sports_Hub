import '../data/inter_clan_games_constants.dart';
import '../models/tournament_model.dart';

class PairMeetingCount {
  final String clanA;
  final String clanB;
  final String game;
  final int count;

  const PairMeetingCount({
    required this.clanA,
    required this.clanB,
    required this.game,
    required this.count,
  });

  bool get isValid =>
      count == InterClanGames2026.expectedMeetingsPerPairPerGame;
}

class ClanSlotBalance {
  final String clan;
  final String game;
  final int slot1Count;
  final int slot2Count;

  const ClanSlotBalance({
    required this.clan,
    required this.game,
    required this.slot1Count,
    required this.slot2Count,
  });

  bool get isValid =>
      slot1Count == InterClanGames2026.expectedSlotBalance &&
      slot2Count == InterClanGames2026.expectedSlotBalance;
}

class FairnessReport {
  final List<PairMeetingCount> pairMeetings;
  final List<ClanSlotBalance> slotBalances;

  const FairnessReport({
    required this.pairMeetings,
    required this.slotBalances,
  });

  bool get allValid =>
      pairMeetings.every((p) => p.isValid) &&
      slotBalances.every((s) => s.isValid);

  int get invalidPairCount => pairMeetings.where((p) => !p.isValid).length;
  int get invalidSlotCount => slotBalances.where((s) => !s.isValid).length;
}

/// Computes fairness invariants from fixture data — no randomizer involved.
class TournamentFairnessCheck {
  TournamentFairnessCheck._();

  static FairnessReport analyze(List<TournamentFixture> fixtures) {
    final pairCounts = <String, int>{};
    final slotCounts = <String, Map<String, int>>{};

    for (final tribe in InterClanGames2026.clans) {
      slotCounts[tribe] = {'slot1': 0, 'slot2': 0};
    }

    for (final fixture in fixtures) {
      final pairKey = _pairKey(fixture.homeClan, fixture.awayClan, fixture.game);
      pairCounts[pairKey] = (pairCounts[pairKey] ?? 0) + 1;

      if (fixture.category != GameCategory.teamSport) continue;

      for (final tribe in [fixture.homeClan, fixture.awayClan]) {
        if (!slotCounts.containsKey(tribe)) continue;
        if (fixture.timeSlot == FixtureTimeSlot.slot1_4pm) {
          slotCounts[tribe]!['slot1'] = slotCounts[tribe]!['slot1']! + 1;
        } else if (fixture.timeSlot == FixtureTimeSlot.slot2_5pm) {
          slotCounts[tribe]!['slot2'] = slotCounts[tribe]!['slot2']! + 1;
        }
      }
    }

    final pairMeetings = <PairMeetingCount>[];
    for (final game in InterClanGames2026.games) {
      for (int i = 0; i < InterClanGames2026.clans.length; i++) {
        for (int j = i + 1; j < InterClanGames2026.clans.length; j++) {
          final a = InterClanGames2026.clans[i];
          final b = InterClanGames2026.clans[j];
          final key = _pairKey(a, b, game);
          pairMeetings.add(PairMeetingCount(
            clanA: a,
            clanB: b,
            game: game,
            count: pairCounts[key] ?? 0,
          ));
        }
      }
    }

    final slotBalances = <ClanSlotBalance>[];
    for (final game in InterClanGames2026.teamSports) {
      for (final clan in InterClanGames2026.clans) {
        final gameFixtures = fixtures.where(
          (f) => f.game == game && f.category == GameCategory.teamSport,
        );
        var slot1 = 0;
        var slot2 = 0;
        for (final f in gameFixtures) {
          if (f.homeClan != clan && f.awayClan != clan) continue;
          if (f.timeSlot == FixtureTimeSlot.slot1_4pm) slot1++;
          if (f.timeSlot == FixtureTimeSlot.slot2_5pm) slot2++;
        }
        slotBalances.add(ClanSlotBalance(
          clan: clan,
          game: game,
          slot1Count: slot1,
          slot2Count: slot2,
        ));
      }
    }

    return FairnessReport(
      pairMeetings: pairMeetings,
      slotBalances: slotBalances,
    );
  }

  static String _pairKey(String a, String b, String game) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}|${sorted[1]}|$game';
  }
}
