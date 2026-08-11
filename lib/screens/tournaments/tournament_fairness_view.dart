import 'package:flutter/material.dart';
import '../../data/inter_clan_games_constants.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';
import '../../utils/tournament_fairness_check.dart';

class TournamentFairnessView extends StatelessWidget {
  final String tournamentId;

  const TournamentFairnessView({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final service = TournamentService();
    return StreamBuilder<List<TournamentFixture>>(
      stream: service.getAllFixtures(tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final fixtures = snapshot.data ?? [];
        if (fixtures.isEmpty) {
          return Center(
            child: Text(
              'No fixtures loaded',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          );
        }

        final report = TournamentFairnessCheck.analyze(fixtures);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(report: report),
            const SizedBox(height: 16),
            Text(
              'Meetings per tribe-pair per game '
              '(expected: ${InterClanGames2026.expectedMeetingsPerPairPerGame})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...report.pairMeetings.map((p) => _PairRow(entry: p)),
            const SizedBox(height: 20),
            Text(
              '4 PM / 5 PM slot balance per tribe per team sport '
              '(expected: ${InterClanGames2026.expectedSlotBalance}-'
              '${InterClanGames2026.expectedSlotBalance})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...report.slotBalances.map((s) => _SlotRow(entry: s)),
          ],
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final FairnessReport report;

  const _StatusBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final ok = report.allValid;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            color: ok ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'All fairness invariants hold (${report.pairMeetings.length} pairs, ${report.slotBalances.length} slot checks).'
                  : '${report.invalidPairCount} pair meeting(s) and '
                      '${report.invalidSlotCount} slot balance(s) deviate from expected values.',
              style: TextStyle(
                color: ok ? Colors.green.shade900 : Colors.red.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairRow extends StatelessWidget {
  final PairMeetingCount entry;

  const _PairRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.isValid ? Icons.check : Icons.close,
        color: entry.isValid ? Colors.green : Colors.red,
        size: 18,
      ),
      title: Text('${entry.clanA} vs ${entry.clanB} — ${entry.game}'),
      trailing: Text(
        '${entry.count}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: entry.isValid ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final ClanSlotBalance entry;

  const _SlotRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.isValid ? Icons.check : Icons.close,
        color: entry.isValid ? Colors.green : Colors.red,
        size: 18,
      ),
      title: Text('${entry.clan} — ${entry.game}'),
      trailing: Text(
        '4PM: ${entry.slot1Count}  /  5PM: ${entry.slot2Count}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: entry.isValid ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}
