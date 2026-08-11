import 'package:flutter/material.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';
import '../../utils/tournament_result_parser.dart';

class TournamentResultsEntryScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentResultsEntryScreen({super.key, required this.tournament});

  @override
  State<TournamentResultsEntryScreen> createState() =>
      _TournamentResultsEntryScreenState();
}

class _TournamentResultsEntryScreenState
    extends State<TournamentResultsEntryScreen> {
  final TournamentService _service = TournamentService();
  int _selectedMatchDay = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results — ${widget.tournament.name}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: 6,
              itemBuilder: (context, index) {
                final md = index + 1;
                final selected = _selectedMatchDay == md;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('MD $md'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedMatchDay = md),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TournamentFixture>>(
              stream: _service.getFixturesByMatchDay(
                widget.tournament.id,
                _selectedMatchDay,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final fixtures = snapshot.data ?? [];
                if (fixtures.isEmpty) {
                  return const Center(child: Text('No fixtures for this day'));
                }
                fixtures.sort((a, b) {
                  final g = a.game.compareTo(b.game);
                  if (g != 0) return g;
                  return a.timeSlot.index.compareTo(b.timeSlot.index);
                });
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: fixtures.length,
                  itemBuilder: (context, index) {
                    return _ResultEntryCard(
                      fixture: fixtures[index],
                      onSubmit: (input) => _submitResult(fixtures[index], input),
                      onClear: () => _clearResult(fixtures[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResult(TournamentFixture fixture, String input) async {
    final error = await _service.enterFixtureResult(
      tournamentId: widget.tournament.id,
      fixtureId: fixture.id,
      rawInput: input,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result saved — points table updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearResult(TournamentFixture fixture) async {
    await _service.clearFixtureResult(
      tournamentId: widget.tournament.id,
      fixtureId: fixture.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result cleared')),
    );
  }
}

class _ResultEntryCard extends StatefulWidget {
  final TournamentFixture fixture;
  final Future<void> Function(String input) onSubmit;
  final VoidCallback onClear;

  const _ResultEntryCard({
    required this.fixture,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  State<_ResultEntryCard> createState() => _ResultEntryCardState();
}

class _ResultEntryCardState extends State<_ResultEntryCard> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final hasResult = f.hasResult;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${f.game} • ${f.stage}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasResult)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${f.homePts}-${f.awayPts} (${TournamentResultParser.label(f.result!)})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${f.homeClan} vs ${f.awayClan}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'A / B / Draw',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.none,
                    onSubmitted: _submitting ? null : _handleSubmit,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
                if (hasResult) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.error),
                    onPressed: widget.onClear,
                    tooltip: 'Clear result',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Team A = ${f.homeClan}  •  Team B = ${f.awayClan}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit([String? _]) async {
    setState(() => _submitting = true);
    await widget.onSubmit(_controller.text);
    if (mounted) {
      setState(() => _submitting = false);
      _controller.clear();
    }
  }
}
