import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});
  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _userData;

  // Predefined sports teams at JC Campus
  final List<Map<String, dynamic>> _sports = [
    {'name': 'Football', 'icon': '⚽', 'color': 0xFF1B5E20},
    {'name': 'Basketball', 'icon': '🏀', 'color': 0xFFE65100},
    {'name': 'Volleyball', 'icon': '🏐', 'color': 0xFF6A1B9A},
    {'name': 'Athletics', 'icon': '🏃', 'color': 0xFF283593},
    {'name': 'Netball', 'icon': '🥅', 'color': 0xFFC62828},
    {'name': 'Chess', 'icon': '♟️', 'color': 0xFF37474F},
    {'name': 'Dart', 'icon': '🎯', 'color': 0xFF00838F},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _userData = doc.data() as Map<String, dynamic>);
    }
  }

  bool get _isGuest => _userData?['userType'] == 'guest';
  bool get _isAdmin =>
      _userData?['isAdmin'] == true || // role-equivalent flag in Firestore
      _userData?['role'] == 'admin' ||
      _userData?['email'] == AppStrings.adminEmail;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isGuest) {
      // Guests (anonymous users) cannot view or register for school teams -
      // they must create/join a registered account first.
      body = _buildGuestRestricted();
    } else if (_userData == null) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('JC Campus Sports Teams',
                  style: TextStyle(
                      fontSize: AppSizes.fontLarge,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Makerere University Jinja Campus',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: AppSizes.fontSmall)),
              const SizedBox(height: 12),
              if (!_isGuest)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap a sport to view the team and register as a player for upcoming matches.',
                        style:
                            TextStyle(color: AppColors.primary, fontSize: 11),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),

          const SizedBox(height: 16),

          // SPORTS GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _sports.length,
            itemBuilder: (context, index) {
              final sport = _sports[index];
              return _buildSportCard(sport);
            },
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: const Text('Teams',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: body,
    );
  }

  Widget _buildGuestRestricted() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Only registered students can view and register for school teams',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an account or sign in to join a team and be part of the JC Campus squads.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/onboarding');
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Create Account / Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(Map<String, dynamic> sport) {
    final Color color = Color(sport['color'] as int);
    return GestureDetector(
      onTap: () => _showTeamDetail(sport),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
                child:
                    Text(sport['icon'], style: const TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 10),
          Text(sport['name'],
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSmall,
                  color: color)),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .where('sport', isEqualTo: sport['name'])
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Text('$count registered players',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10));
            },
          ),
        ]),
      ),
    );
  }

  void _showTeamDetail(Map<String, dynamic> sport) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _TeamDetailSheet(
        sport: sport,
        currentUserId: _currentUserId,
        userData: _userData,
        isGuest: _isGuest,
        isAdmin: _isAdmin,
      ),
    );
  }
}

class _TeamDetailSheet extends StatefulWidget {
  final Map<String, dynamic> sport;
  final String? currentUserId;
  final Map<String, dynamic>? userData;
  final bool isGuest;
  final bool isAdmin;

  const _TeamDetailSheet({
    required this.sport,
    required this.currentUserId,
    required this.userData,
    required this.isGuest,
    required this.isAdmin,
  });

  @override
  State<_TeamDetailSheet> createState() => _TeamDetailSheetState();
}

class _TeamDetailSheetState extends State<_TeamDetailSheet> {
  final TextEditingController _jerseyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  bool _isRegistering = false;
  bool _isAlreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  @override
  void dispose() {
    _jerseyController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    if (widget.currentUserId == null) return;
    final existing = await FirebaseFirestore.instance
        .collection('teams')
        .where('userId', isEqualTo: widget.currentUserId)
        .where('sport', isEqualTo: widget.sport['name'])
        .get();
    if (mounted) {
      setState(() => _isAlreadyRegistered = existing.docs.isNotEmpty);
    }
  }

  Future<void> _registerAsPlayer() async {
    if (_jerseyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter your jersey number'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await FirebaseFirestore.instance.collection('teams').add({
        'userId': widget.currentUserId,
        'userName': widget.userData?['fullName'] ?? 'Player',
        'userType': widget.userData?['userType'] ?? 'bachelor',
        'sport': widget.sport['name'],
        'jerseyNumber': _jerseyController.text.trim(),
        'position': _positionController.text.trim(),
        'isVerified': false,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isRegistering = false;
        _isAlreadyRegistered = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registered! Waiting for admin verification.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Color(widget.sport['color'] as int);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(children: [
          // HANDLE
          const SizedBox(height: 12),
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(widget.sport['icon'], style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.sport['name'] + ' Team',
                    style: TextStyle(
                        fontSize: AppSizes.fontLarge,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const Text('JC Campus',
                    style: TextStyle(
                        color: Colors.grey, fontSize: AppSizes.fontSmall)),
              ]),
            ]),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // REGISTER SECTION
                if (!widget.isGuest && !_isAlreadyRegistered) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Register as Player',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: AppSizes.fontMedium)),
                          const SizedBox(height: 4),
                          const Text(
                              'Register to participate in matches. Admin will verify your registration.',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _jerseyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Jersey Number',
                              hintText: 'e.g. 10',
                              prefixIcon:
                                  Icon(Icons.sports_soccer, color: color),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMedium)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMedium),
                                borderSide: BorderSide(color: color, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _positionController,
                            decoration: InputDecoration(
                              labelText: 'Position (optional)',
                              hintText: 'e.g. Forward, Goalkeeper',
                              prefixIcon: Icon(Icons.person, color: color),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMedium)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMedium),
                                borderSide: BorderSide(color: color, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isRegistering ? null : _registerAsPlayer,
                              icon: _isRegistering
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.how_to_reg),
                              label: const Text('Register as Player'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMedium)),
                              ),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isAlreadyRegistered && !widget.isAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                          'You are registered for this team. Admin will verify you.',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: AppSizes.fontSmall)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // PLAYERS LIST
                Text('Registered Players',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontMedium,
                        color: color)),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('teams')
                      .where('sport', isEqualTo: widget.sport['name'])
                      .where('isVerified', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary));
                    }
                    final players = snapshot.data?.docs ?? [];
                    if (players.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No verified players yet',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      );
                    }
                    return Column(
                      children: players.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMedium),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Row(children: [
                            // Jersey number badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Center(
                                child: Text(data['jerseyNumber'] ?? '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(data['userName'] ?? 'Player',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: AppSizes.fontSmall)),
                                  if (data['position'] != null &&
                                      data['position'].toString().isNotEmpty)
                                    Text(data['position'],
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11)),
                                ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                  data['userType'] == 'bachelor'
                                      ? 'BSc'
                                      : 'Dip',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            // Admin can verify/remove
                            if (widget.isAdmin) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 18),
                                onPressed: () async =>
                                    await doc.reference.delete(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ]),
                        );
                      }).toList(),
                    );
                  },
                ),

                // PENDING PLAYERS (admin only)
                if (widget.isAdmin) ...[
                  const SizedBox(height: 16),
                  const Text('Pending Verification',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontMedium,
                          color: Colors.orange)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('teams')
                        .where('sport', isEqualTo: widget.sport['name'])
                        .where('isVerified', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final pending = snapshot.data?.docs ?? [];
                      if (pending.isEmpty) {
                        return Text('No pending registrations.',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: AppSizes.fontSmall));
                      }
                      return Column(
                        children: pending.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMedium),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text(data['jerseyNumber'] ?? '?',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(data['userName'] ?? 'Player',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: AppSizes.fontSmall)),
                                    if (data['position'] != null &&
                                        data['position'].toString().isNotEmpty)
                                      Text(data['position'],
                                          style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11)),
                                  ])),
                              ElevatedButton(
                                onPressed: () async {
                                  await doc.reference
                                      .update({'isVerified': true});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(data['userName'] +
                                                ' verified!'),
                                            backgroundColor: Colors.green,
                                            behavior:
                                                SnackBarBehavior.floating));
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Verify',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppColors.error, size: 18),
                                onPressed: () async =>
                                    await doc.reference.delete(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ]),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ]);
      },
    );
  }
}
