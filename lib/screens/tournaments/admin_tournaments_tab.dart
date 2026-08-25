// lib/screens/tournaments/admin_tournaments_tab.dart
import 'package:flutter/material.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';

import 'tournament_results_entry_screen.dart';
import 'clan_registration_screen.dart';

class AdminTournamentsTab extends StatefulWidget {
  const AdminTournamentsTab({super.key});

  @override
  State<AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<AdminTournamentsTab> {
  final TournamentService _tournamentService = TournamentService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Tournament Management',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createVerifiedInterClanGames,
                icon: const Icon(Icons.emoji_events, size: 20),
                label: const Text('Add Inter-Tribe 2026'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TournamentModel>>(
            stream: _tournamentService.getAdminTournaments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final tournaments = snapshot.data ?? [];
              if (tournaments.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No tournaments created yet',
                        style: TextStyle(
                          fontSize: AppSizes.fontLarge,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tournament = tournaments[index];
                  return _TournamentCard(
                    tournament: tournament,
                    onViewFixtures: () => _viewFixtures(tournament),
                    onViewPoints: () => _viewPoints(tournament),
                    onEnterResults: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentResultsEntryScreen(
                          tournament: tournament,
                        ),
                      ),
                    ),
                    onManageRegistration: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TribeRegistrationScreen(tournament: tournament),
                      ),
                    ),
                    onUpdateStatus: (status) {
                      final tournamentStatus =
                          TournamentStatus.values.firstWhere(
                        (e) => e.name == status,
                        orElse: () => TournamentStatus.upcoming,
                      );
                      _tournamentService.updateTournamentStatus(
                          tournament.id, tournamentStatus);
                    },
                    onReseed: () async {
                      await _tournamentService.reseedFixtures(tournament.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fixtures reseeded and points recalculated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    onPublish: () async {
                      final result =
                          await _tournamentService.publishFixturesToMatches(
                              tournament.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] as String? ?? ''),
                            backgroundColor: result['success'] == true
                                ? Colors.green
                                : AppColors.error,
                          ),
                        );
                      }
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete tournament?'),
                          content: Text(
                            'This will permanently delete "${tournament.name}" and all its fixtures, registrations, and points.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _tournamentService.deleteTournament(tournament.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tournament deleted'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createVerifiedInterClanGames() async {
    await _tournamentService.createInterClanGames2026();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Inter-Tribe Games 2026 created with verified fixtures.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _viewFixtures(TournamentModel tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FixturesScreen(tournament: tournament),
      ),
    );
  }

  void _viewPoints(TournamentModel tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PointsScreen(tournament: tournament),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onViewFixtures;
  final VoidCallback onViewPoints;
  final VoidCallback onEnterResults;
  final VoidCallback onManageRegistration;
  final Function(String) onUpdateStatus;
  final VoidCallback onReseed;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  const _TournamentCard({
    required this.tournament,
    required this.onViewFixtures,
    required this.onViewPoints,
    required this.onEnterResults,
    required this.onManageRegistration,
    required this.onUpdateStatus,
    required this.onReseed,
    required this.onPublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = tournament.status == TournamentStatus.ongoing
        ? Colors.green
        : tournament.status == TournamentStatus.upcoming
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.emoji_events, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Season ${tournament.season}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    tournament.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reg: ${tournament.registrationOpen.day}/${tournament.registrationOpen.month} - ${tournament.registrationClose.day}/${tournament.registrationClose.month}/2026',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.sports_soccer, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'League: ${tournament.leagueStart.day}/${tournament.leagueStart.month} - ${tournament.leagueEnd.day}/${tournament.leagueEnd.month}/2026',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.groups, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${tournament.tribes.length} tribes • ${tournament.games.length} games',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManageRegistration,
                    icon: Icon(Icons.groups_outlined, size: 16),
                    label: Text('Registrations', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewFixtures,
                    icon: Icon(Icons.calendar_month, size: 16),
                    label: Text('Fixtures', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEnterResults,
                    icon: Icon(Icons.edit_note, size: 16),
                    label: Text('Results', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewPoints,
                    icon: Icon(Icons.bar_chart, size: 16),
                    label: Text('Points', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPublish,
                    icon: Icon(Icons.campaign_outlined, size: 16),
                    label: Text('Publish', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReseed,
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('Reseed', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 16),
                    label: Text('Delete', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FixturesScreen extends StatelessWidget {
  final TournamentModel tournament;

  const _FixturesScreen({required this.tournament});

  Future<void> _editFixture(
    BuildContext context,
    TournamentService service,
    TournamentModel tournament,
    TournamentFixture fixture,
  ) async {
    final home = TextEditingController(text: fixture.homeClan);
    final away = TextEditingController(text: fixture.awayClan);
    var game = fixture.game;
    var category = fixture.category;
    var timeSlot = fixture.timeSlot;
    var date = fixture.date;
    var saveMessage = '';
    var saved = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: date,
              firstDate: DateTime(tournament.registrationOpen.year - 1, 1, 1),
              lastDate: DateTime(tournament.leagueEnd.year + 1, 12, 31),
            );
            if (picked != null) setDialogState(() => date = picked);
          }

          Future<void> selectGame(String g) async {
            setDialogState(() {
              game = g;
              category = categoryForGame(g);
              if (category == GameCategory.mindGame) {
                timeSlot = FixtureTimeSlot.mind_3pm;
              } else if (timeSlot == FixtureTimeSlot.mind_3pm) {
                timeSlot = FixtureTimeSlot.slot1_4pm;
              }
            });
          }

          return AlertDialog(
            title: Text('Edit ${fixture.homeClan} vs ${fixture.awayClan}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fixture.result != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Result: ${fixture.homePts} - ${fixture.awayPts} '
                        '(${fixture.result!.name.toUpperCase()})',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Game',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in tournament.games)
                              if (game == g)
                                FilledButton(
                                  onPressed: () => selectGame(g),
                                  child: Text(g),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () => selectGame(g),
                                  child: Text(g),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time slot',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in FixtureTimeSlot.values)
                              if (timeSlot == slot)
                                FilledButton(
                                  onPressed: () =>
                                      setDialogState(() => timeSlot = slot),
                                  child: Text(timeSlotLabel(slot)),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () =>
                                      setDialogState(() => timeSlot = slot),
                                  child: Text(timeSlotLabel(slot)),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.calendar_today, color: AppColors.primary),
                    title: Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    ),
                    subtitle: const Text('Tap to change the date'),
                    onTap: pickDate,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: home,
                    decoration: const InputDecoration(
                      labelText: 'Home tribe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: away,
                    decoration: const InputDecoration(
                      labelText: 'Away tribe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (home.text.trim().isEmpty || away.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Home and away tribes are required')),
                    );
                    return;
                  }
                  final edited = TournamentFixture(
                    id: fixture.id,
                    tournamentId: fixture.tournamentId,
                    game: game,
                    matchDay: fixture.matchDay,
                    round: fixture.round,
                    category: category,
                    timeSlot: timeSlot,
                    stage: fixture.stage,
                    date: date,
                    homeClan: home.text.trim(),
                    awayClan: away.text.trim(),
                    result: fixture.result,
                    homePts: fixture.homePts,
                    awayPts: fixture.awayPts,
                    notes: fixture.notes,
                  );
                  final result =
                      await service.updateFixture(tournament.id, edited);
                  saveMessage = result['message'] as String? ?? '';
                  saved = result['success'] == true;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    home.dispose();
    away.dispose();
    if (!context.mounted) return;
    if (saveMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saveMessage),
          backgroundColor: saved ? Colors.green : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = TournamentService();
    return Scaffold(
      appBar: AppBar(
        title: Text('${tournament.name} Fixtures'),
      ),
      body: StreamBuilder<List<TournamentFixture>>(
        stream: service.getAllFixtures(tournament.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final fixtures = snapshot.data ?? [];
          if (fixtures.isEmpty) {
            return const Center(
              child: Text('No fixtures loaded'),
            );
          }

          final grouped = <String, List<TournamentFixture>>{};
          final monthAbbr = const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          for (final f in fixtures) {
            final dateKey =
                '${f.date.day.toString().padLeft(2, '0')}-${monthAbbr[f.date.month - 1]}-${f.date.year}';
            final dayName = [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ][f.date.weekday - 1];
            final key = '$dateKey|$dayName|${f.game}';
            grouped.putIfAbsent(key, () => []).add(f);
          }

          final rows = grouped.entries.toList();
          rows.sort((a, b) {
            final dateA = a.key.split('|').first;
            final dateB = b.key.split('|').first;
            return dateA.compareTo(dateB);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final entry = rows[index];
              final parts = entry.key.split('|');
              final dateStr = parts[0];
              final dayStr = parts[1];
              final game = parts[2];
              final gameFixtures = entry.value;
              final timeLabel = gameFixtures[0].category == GameCategory.mindGame
                  ? '3:00 PM (both simultaneous)'
                  : '${timeSlotLabel(FixtureTimeSlot.slot1_4pm)}  /  '
                      '${timeSlotLabel(FixtureTimeSlot.slot2_5pm)}';

              final isGoldRow = gameFixtures[0].date.month == 11 &&
                  gameFixtures[0].date.day == 11;

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                color: isGoldRow ? Colors.amber.shade50 : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dateStr,$dayStr,$game,$timeLabel',
                        style: TextStyle(
                          fontWeight:
                              isGoldRow ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                          color: isGoldRow ? Colors.amber.shade900 : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final fixture in gameFixtures)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    '${fixture.homeClan} vs ${fixture.awayClan}'),
                              ),
                              if (fixture.result != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    '${fixture.homePts} - ${fixture.awayPts}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 16,
                                  visualDensity: VisualDensity.compact,
                                  color: Colors.grey.shade600,
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit fixture',
                                  onPressed: () => _editFixture(
                                      context, service, tournament, fixture),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PointsScreen extends StatelessWidget {
  final TournamentModel tournament;

  const _PointsScreen({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final service = TournamentService();
    return Scaffold(
      appBar: AppBar(
        title: Text('${tournament.name} Points Table'),
      ),
      body: StreamBuilder<List<TournamentPoints>>(
        stream: service.getPointsTable(tournament.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final points = snapshot.data ?? [];
          if (points.isEmpty) {
            return Center(
              child: Text(
                'No points calculated yet',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: points.length,
            itemBuilder: (context, index) {
              final point = points[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                  child: Text(
                    point.rank.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  ),
                  title: Text(point.tribe),
                  subtitle: Text('Total: ${point.totalPoints} pts'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: point.gamePoints.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
