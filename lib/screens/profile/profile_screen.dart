import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

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
      setState(() {
        _userData = doc.data() as Map<String, dynamic>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: const Text('My Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // PROFILE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            _userData?['fullName'] != null
                                ? (_userData!['fullName'] as String)[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_userData?['fullName'] ?? 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppSizes.fontLarge,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_userData?['email'] ?? '',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: AppSizes.fontSmall)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getUserTypeLabel(_userData?['userType'] ?? 'guest'),
                            style: const TextStyle(color: Colors.white, fontSize: AppSizes.fontSmall),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // WALLET BALANCE
                  StreamBuilder<int>(
                    stream: _currentUserId != null
                        ? _walletService.getBalanceStream(_currentUserId!)
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Wallet Balance',
                                    style: TextStyle(color: Colors.grey, fontSize: AppSizes.fontSmall)),
                                Text(
                                  _formatAmount(balance) + ' UGX',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppSizes.fontLarge,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // STATS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                            (_userData?['badgeCount'] ?? 0).toString(),
                            'Badges', Icons.emoji_events, AppColors.gold),
                        Container(height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatItem(
                            _userData?['userType'] == 'bachelor'
                                ? 'BSc'
                                : _userData?['userType'] == 'diploma'
                                    ? 'Diploma'
                                    : 'Guest',
                            'Account Type', Icons.school, AppColors.primary),
                        Container(height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatItem(
                            _userData?['isVerified'] == true ? 'Yes' : 'No',
                            'Verified', Icons.verified, Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // LOGOUT
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _authService.logout();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/onboarding');
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppSizes.fontMedium, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'bachelor': return 'Bachelor Student';
      case 'diploma': return 'Diploma Student';
      case 'admin': return 'Administrator';
      default: return 'Community Guest';
    }
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => m[1]! + ',');
  }
}