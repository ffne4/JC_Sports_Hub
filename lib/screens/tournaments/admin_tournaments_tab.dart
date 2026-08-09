// lib/screens/tournaments/admin_tournaments_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';

class AdminTournamentsTab extends StatefulWidget {
  const AdminTournamentsTab({super.key});

  @override
  State<AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<AdminTournamentsTab>
    with SingleTickerProviderStateMixin {
  final TournamentService _tournamentService = TournamentService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();
  final TextEditingController _adminNotesController = TextEditingController();
  bool _isCreating = false;
  String _selectedStatus = 'upcoming';
  DateTime _registrationOpen = DateTime.now();
  DateTime _registrationClose = DateTime.now().add(const Duration(days: 7));
  DateTime _leagueStart = DateTime.now().add(const Duration(days: 8));
  DateTime _leagueEnd = DateTime.now().add(const Duration(days: 70));
  DateTime? _finalsStart;
  DateTime? _finalsEnd;
  DateTime? _closingCeremony;

  final List<String> _courses = [
    'Electrical',
    'Civil',
    'Business',
    'Arts',
    'BIST',
    'Computer Science',
  ];

  final List<String> _games = [
    'Football',
    'Netball',
    'Volleyball',
    'Chess',
    'Scrabble',
    'Ludo',
    'Matatu/Cards',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    _adminNotesController.dispose();
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
              const Text(
                'Tournament Management',
                style: TextStyle(
                  fontSize: AppSizes.fontLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create Tournament'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TournamentModel>>(
            stream: _tournamentService.getActiveTournaments(),
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
                    onUpdateStatus: (status) {
                      final tournamentStatus =
                          TournamentStatus.values.firstWhere(
                        (e) => e.name == status,
                        orElse: () => TournamentStatus.upcoming,
                      );
                      _tournamentService.updateTournamentStatus(
                          tournament.id, tournamentStatus);
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

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Tournament'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tournament Name',
                  hintText: 'e.g. JC Sports Hub Cup 2026',
                ),
              ),
              TextField(
                controller: _seasonController,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  hintText: 'e.g. 2026/2027',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Status'),
              DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                  DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                ],
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
                },
              ),
              const SizedBox(height: 16),
              const Text('Registration Period'),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickDate(
                        context,
                        _registrationOpen,
                        (date) => setState(() => _registrationOpen = date),
                      ),
                      child: Text(
                        'From: ${_registrationOpen.day}/${_registrationOpen.month}/${_registrationOpen.year}',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickDate(
                        context,
                        _registrationClose,
                        (date) => setState(() => _registrationClose = date),
                      ),
                      child: Text(
                        'To: ${_registrationClose.day}/${_registrationClose.month}/${_registrationClose.year}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('League Phase'),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickDate(
                        context,
                        _leagueStart,
                        (date) => setState(() => _leagueStart = date),
                      ),
                      child: Text(
                        'Start: ${_leagueStart.day}/${_leagueStart.month}/${_leagueStart.year}',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickDate(
                        context,
                        _leagueEnd,
                        (date) => setState(() => _leagueEnd = date),
                      ),
                      child: Text(
                        'End: ${_leagueEnd.day}/${_leagueEnd.month}/${_leagueEnd.year}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Courses'),
              Wrap(
                spacing: 8,
                children: _courses.map((course) {
                  return FilterChip(
                    label: Text(course),
                    selected: false,
                    onSelected: (selected) {},
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Games'),
              Wrap(
                spacing: 8,
                children: _games.map((game) {
                  return FilterChip(
                    label: Text(game),
                    selected: false,
                    onSelected: (selected) {},
                  );
                }).toList(),
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
            onPressed: _isCreating
                ? null
                : () async {
                    setState(() => _isCreating = true);
                    final tournament = TournamentModel(
                      id: '',
                      name: _nameController.text,
                      season: _seasonController.text,
                      status: TournamentStatus.values.firstWhere(
                        (e) => e.name == _selectedStatus,
                        orElse: () => TournamentStatus.upcoming,
                      ),
                      registrationOpen: _registrationOpen,
                      registrationClose: _registrationClose,
                      leagueStart: _leagueStart,
                      leagueEnd: _leagueEnd,
                      finalsStart: _finalsStart,
                      finalsEnd: _finalsEnd,
                      closingCeremony: _closingCeremony,
                      courses: _courses,
                      games: _games,
                      createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
                      createdAt: DateTime.now(),
                      isActive: true,
                    );
                    await _tournamentService.createTournament(tournament);
                    setState(() => _isCreating = false);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tournament created with fixtures'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: _isCreating
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime current,
    Function(DateTime) onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2026),
      lastDate: DateTime(2030),
    );
    if (picked != null) onPicked(picked);
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
  final Function(String) onUpdateStatus;

  const _TournamentCard({
    required this.tournament,
    required this.onViewFixtures,
    required this.onViewPoints,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = tournament.status == TournamentStatus.ongoing
        ? Colors.green
        : tournament.status == TournamentStatus.upcoming
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tournament.name,
                    style: const TextStyle(
                      fontSize: AppSizes.fontMedium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 8),
            Text(
              'Season: ${tournament.season}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Registration: ${tournament.registrationOpen.day}/${tournament.registrationOpen.month} - ${tournament.registrationClose.day}/${tournament.registrationClose.month}/2026',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewFixtures,
                    icon: const Icon(Icons.sports_soccer, size: 18),
                    label: const Text('Fixtures'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewPoints,
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('Points'),
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

  @override
  Widget build(BuildContext context) {
    final service = TournamentService();
    return DefaultTabController(
      length: tournament.games.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${tournament.name} Fixtures'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tournament.games
                .map((game) => Tab(
                      text: game,
                      icon: Icon(_getGameIcon(game)),
                    ))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: tournament.games.map((game) {
            return StreamBuilder<List<TournamentFixture>>(
              stream: service.getFixturesByGame(tournament.id, game),
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
                      'No fixtures for $game yet',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: fixtures.length,
                  itemBuilder: (context, index) {
                    final fixture = fixtures[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading:
                            Icon(_getGameIcon(game), color: AppColors.primary),
                        title: Text(
                            '${fixture.homeCourse} vs ${fixture.awayCourse}'),
                        subtitle: Text(
                          '${fixture.date.day}/${fixture.date.month}/${fixture.date.year} • ${fixture.stage}',
                        ),
                        trailing: fixture.result != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  fixture.result!,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getGameIcon(String game) {
    switch (game) {
      case 'Football':
        return Icons.sports_soccer;
      case 'Netball':
        return Icons.sports_basketball;
      case 'Volleyball':
        return Icons.sports_volleyball;
      case 'Chess':
        return Icons.public;
      case 'Scrabble':
        return Icons.text_fields;
      case 'Ludo':
        return Icons.casino;
      case 'Matatu/Cards':
        return Icons.directions_car;
      default:
        return Icons.sports;
    }
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
                  title: Text(point.course),
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
