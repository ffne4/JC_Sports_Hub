// lib/screens/tournaments/tournaments_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  final TournamentService _tournamentService = TournamentService();
  late TabController _tabController;
  String? _currentTournamentId;
  TournamentModel? _currentTournament;
  bool _isLoading = true;
  String? _selectedCourse;
  String? _selectedGame;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        _currentTournamentId = tournament?.id;
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
    final isGuest = user == null;

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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Season: ${tournament.season}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              Icons.calendar_today,
                              'Reg: ${tournament.registrationOpen.day}/${tournament.registrationOpen.month} - ${tournament.registrationClose.day}/${tournament.registrationClose.month}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              Icons.sports_soccer,
                              'League: ${tournament.leagueStart.day}/${tournament.leagueStart.month} - ${tournament.leagueEnd.day}/${tournament.leagueEnd.month}',
                            ),
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
            isGuest ? _buildGuestPrompt() : _buildRegistrationTab(tournament),
            _buildStandingsTab(tournament),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
    return DefaultTabController(
      length: tournament.games.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: tournament.games
                .map((game) => Tab(
                      text: game,
                      icon: Icon(_getGameIcon(game), size: 18),
                    ))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: tournament.games.map((game) {
                return StreamBuilder<List<TournamentFixture>>(
                  stream: service.getFixturesByGame(tournament.id, game),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
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
                      padding: const EdgeInsets.all(12),
                      itemCount: fixtures.length,
                      itemBuilder: (context, index) {
                        final fixture = fixtures[index];
                        final isPast = fixture.date.isBefore(DateTime.now());
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              _getGameIcon(game),
                              color: isPast ? Colors.grey : AppColors.primary,
                            ),
                            title: Text(
                              '${fixture.homeCourse} vs ${fixture.awayCourse}',
                              style: TextStyle(
                                fontWeight: isPast
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${fixture.date.day}/${fixture.date.month}/${fixture.date.year} • ${fixture.stage ?? ''}',
                                ),
                                if (fixture.result != null)
                                  Text(
                                    'Result: ${fixture.result}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
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
                                      '${fixture.homePts} - ${fixture.awayPts}',
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
        ],
      ),
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
    if (_selectedCourse == null || _selectedGame == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.how_to_reg_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Select course and game to register',
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

        final userData = (snapshot.data!.data() as Map<String, dynamic>) ?? {};
        final studentName =
            userData['fullName'] ?? user.displayName ?? 'Student';
        final studentNumber = userData['regNumber'] ?? '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedCourse • $_selectedGame',
                      style: const TextStyle(
                        fontSize: AppSizes.fontMedium,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                'Select Course',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: tournament.courses.map((course) {
                  final isSelected = _selectedCourse == course;
                  return ChoiceChip(
                    label: Text(course),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCourse = course;
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
                        setState(() => _selectedGame = game);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FutureBuilder<bool>(
                future: _isAlreadyRegistered(
                    tournament.id, _selectedCourse!, _selectedGame!),
                builder: (context, snapshot) {
                  final isRegistered = snapshot.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isRegistered
                          ? null
                          : () async {
                              if (_selectedCourse == null ||
                                  _selectedGame == null) return;
                              final success =
                                  await _tournamentService.registerStudent(
                                tournamentId: tournament.id,
                                course: _selectedCourse!,
                                game: _selectedGame!,
                                studentName: studentName,
                                studentNumber: studentNumber,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'Registered successfully'
                                        : 'Already registered for this course+game'),
                                    backgroundColor: success
                                        ? Colors.green
                                        : AppColors.error,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        isRegistered ? 'Already Registered' : 'Register Now',
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
      String tournamentId, String course, String game) async {
    final registrations =
        await _tournamentService.getStudentRegistrations(tournamentId);
    return registrations.any((r) => r.course == course && r.game == game);
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
        return ListView.builder(
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: rankColor ?? AppColors.primary,
                      child: Text(
                        '${point.rank}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.course,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.fontSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: point.gamePoints.entries.map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
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
        );
      },
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
