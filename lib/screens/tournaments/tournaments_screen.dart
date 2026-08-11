// lib/screens/tournaments/tournaments_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';
import 'tournament_fairness_view.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  final TournamentService _tournamentService = TournamentService();
  late TabController _tabController;
  TournamentModel? _currentTournament;
  bool _isLoading = true;
  String? _selectedTribe;
  String? _selectedGame;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentTournament();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTournament() async {
    final tournament = await _tournamentService.getCurrentTournament().first;
    if (mounted) {
      setState(() {
        _currentTournament = tournament;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_currentTournament == null) {
      return const Scaffold(
        body: Center(
          child: Text('No active tournament currently',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final tournament = _currentTournament!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildGuestPrompt();
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tournament.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppSizes.fontLarge,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildStatusChip(tournament.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Season ${tournament.season}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Inter-tribe league: ${tournament.tribes.length} tribes, ${tournament.games.length} games, 6 match-days.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            Icons.calendar_today,
                            'Reg: ${_formatShortDate(tournament.registrationOpen)} - ${_formatShortDate(tournament.registrationClose)}',
                          ),
                          _buildInfoChip(
                            Icons.sports_soccer,
                            'League: ${_formatShortDate(tournament.leagueStart)} - ${_formatShortDate(tournament.leagueEnd)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Fixtures'),
                    Tab(text: 'Register'),
                    Tab(text: 'Standings'),
                    Tab(text: 'Fairness'),
                  ],
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFixturesTab(tournament),
            _buildRegistrationTab(tournament),
            _buildStandingsTab(tournament),
            TournamentFairnessView(tournamentId: tournament.id),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixturesTab(TournamentModel tournament) {
    final service = TournamentService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'MATCH SCHEDULE — 19 AUG 2026 TO 11 NOV 2026 (WED & FRI ONLY)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TournamentFixture>>(
            stream: service.getAllFixtures(tournament.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary),
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
                  final match1 =
                      gameFixtures[0].homeClan + ' vs ' + gameFixtures[0].awayClan;
                  final match2 = gameFixtures.length > 1
                      ? gameFixtures[1].homeClan +
                          ' vs ' +
                          gameFixtures[1].awayClan
                      : '';
                  final timeLabel = gameFixtures[0].category == GameCategory.mindGame
                      ? '3:00 PM (both simultaneous)'
                      : '${timeSlotLabel(FixtureTimeSlot.slot1_4pm)}  /  ${timeSlotLabel(FixtureTimeSlot.slot2_5pm)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$dateStr,$dayStr,$game,$timeLabel',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(match1),
                                if (match2.isNotEmpty) Text(match2),
                              ],
                            ),
                          ),
                          if (gameFixtures[0].result != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${gameFixtures[0].homePts} - ${gameFixtures[0].awayPts}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
        ),
      ],
    );
  }

  Widget _buildGuestPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Login to register',
              style: TextStyle(
                fontSize: AppSizes.fontLarge,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a student account to join a tournament squad',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTab(TournamentModel tournament) {
    final selectedTribe = _selectedTribe;
    final selectedGame = _selectedGame;

    if (selectedTribe == null || selectedGame == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.how_to_reg_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Select tribe and game to register',
                style: TextStyle(
                  fontSize: AppSizes.fontLarge,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
              child: Text('User profile not found',
                  style: TextStyle(color: Colors.red)));
        }

        final data = snapshot.data?.data();
        final userData =
            (data is Map<String, dynamic>) ? data : <String, dynamic>{};
        final studentName =
            userData['fullName'] ?? user.displayName ?? 'Student';
        final studentNumber = userData['regNumber'] ?? '';

        final isRegistrationOpen = _isRegistrationOpen(
          tournament.registrationOpen,
          tournament.registrationClose,
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRegistrationOpen
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline,
                          color: isRegistrationOpen
                              ? Colors.green.shade700
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isRegistrationOpen
                                ? 'Registration is open now'
                                : 'Registration window is closed',
                            style: const TextStyle(
                              fontSize: AppSizes.fontMedium,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_selectedTribe • $_selectedGame',
                      style: const TextStyle(
                        fontSize: AppSizes.fontMedium,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Student: $studentName',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (studentNumber.isNotEmpty)
                      Text(
                        'Reg No: $studentNumber',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Tribe',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: tournament.tribes.map((tribe) {
                  final isSelected = _selectedTribe == tribe;
                  return ChoiceChip(
                    label: Text(tribe),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTribe = tribe;
                          _selectedGame = null;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Game',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: tournament.games.map((game) {
                  final isSelected = _selectedGame == game;
                  return ChoiceChip(
                    label: Text(game),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedGame = game;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FutureBuilder<bool>(
                future: _isAlreadyRegistered(
                    tournament.id, selectedTribe, selectedGame),
                builder: (context, snapshot) {
                  final isRegistered = snapshot.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isRegistered || !isRegistrationOpen
                          ? null
                          : () async {
                              final success =
                                  await _tournamentService.registerStudent(
                                tournamentId: tournament.id,
                                tribe: selectedTribe,
                                game: selectedGame,
                                studentName: studentName,
                                studentNumber: studentNumber,
                              );
                              if (!mounted || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Registered successfully'
                                      : 'Already registered for this tribe+game'),
                                  backgroundColor:
                                      success ? Colors.green : AppColors.error,
                                ),
                              );
                              setState(() {});
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        isRegistered
                            ? 'Already Registered'
                            : isRegistrationOpen
                                ? 'Register Now'
                                : 'Registration Closed',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _isAlreadyRegistered(
      String tournamentId, String tribe, String game) async {
    final registrations =
        await _tournamentService.getStudentRegistrations(tournamentId);
    return registrations.any((r) => r.tribe == tribe && r.game == game);
  }

  Widget _buildStandingsTab(TournamentModel tournament) {
    final service = TournamentService();
    return StreamBuilder<List<TournamentPoints>>(
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Current leaderboard',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                     Text(
                      '${points.length} tribes',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final point = points[index];
                  final rankColor = point.rank == 1
                      ? Colors.amber[700]
                      : point.rank == 2
                          ? Colors.grey[500]
                          : point.rank == 3
                              ? Colors.brown[500]
                              : AppColors.primary;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: rankColor ?? AppColors.primary,
                            child: Text(
                              '${point.rank}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text(
                                   point.tribe,
                                   style: const TextStyle(
                                     fontWeight: FontWeight.bold,
                                     fontSize: AppSizes.fontSmall,
                                   ),
                                 ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children:
                                      point.gamePoints.entries.map((entry) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${entry.key.split('/').first}: ${entry.value}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF2E7D32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${point.totalPoints} pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(TournamentStatus status) {
    final color = status == TournamentStatus.ongoing
        ? Colors.green.shade100
        : status == TournamentStatus.completed
            ? Colors.grey.shade200
            : Colors.amber.shade100;
    final textColor = status == TournamentStatus.ongoing
        ? Colors.green.shade800
        : status == TournamentStatus.completed
            ? Colors.grey.shade800
            : Colors.amber.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getStatusLabel(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.ongoing:
        return 'LIVE';
      case TournamentStatus.completed:
        return 'DONE';
      case TournamentStatus.upcoming:
        return 'UPCOMING';
    }
  }

  bool _isRegistrationOpen(DateTime open, DateTime close) {
    final now = DateTime.now();
    return !now.isBefore(open) && !now.isAfter(close);
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
