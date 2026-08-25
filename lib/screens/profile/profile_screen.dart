import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';

// Free, hosted avatar images (no Firebase Storage cost). Each is a static
// unique cartoon-style face generated from the dicebear HTTP API. They are
// served as PNG so Flutter's built-in Image.network / NetworkImage can decode
// them (Flutter cannot render the SVG output natively).
class AvatarOption {
  final String name;
  final String color;
  final String url;
  const AvatarOption(this.name, this.color, this.url);
}

final List<AvatarOption> avatarOptions = [
  AvatarOption('Lion', 'amber', 'https://api.dicebear.com/7.x/adventurer/png?seed=Lion&backgroundColor=FFB300&size=256'),
  AvatarOption('Panda', 'green', 'https://api.dicebear.com/7.x/adventurer/png?seed=Panda&backgroundColor=1B5E20&size=256'),
  AvatarOption('Tiger', 'orange', 'https://api.dicebear.com/7.x/adventurer/png?seed=Tiger&backgroundColor=FF6F00&size=256'),
  AvatarOption('Falcon', 'blue', 'https://api.dicebear.com/7.x/adventurer/png?seed=Falcon&backgroundColor=1565C0&size=256'),
  AvatarOption('Wolf', 'purple', 'https://api.dicebear.com/7.x/adventurer/png?seed=Wolf&backgroundColor=6A1B9A&size=256'),
  AvatarOption('Eagle', 'red', 'https://api.dicebear.com/7.x/adventurer/png?seed=Eagle&backgroundColor=C62828&size=256'),
  AvatarOption('Shark', 'teal', 'https://api.dicebear.com/7.x/adventurer/png?seed=Shark&backgroundColor=00838F&size=256'),
  AvatarOption('Leopard', 'brown', 'https://api.dicebear.com/7.x/adventurer/png?seed=Leopard&backgroundColor=6D4C41&size=256'),
  AvatarOption('Fox', 'pink', 'https://api.dicebear.com/7.x/adventurer/png?seed=Fox&backgroundColor=F48FB1&size=256'),
  AvatarOption('Bear', 'indigo', 'https://api.dicebear.com/7.x/adventurer/png?seed=Bear&backgroundColor=3949AB&size=256'),
];

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

  // Lets the user pick a preset avatar (stored as a small index in the
  // users document - no Firebase Storage / real upload is needed).
  void _pickAvatar() {
    final stateContext = context;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose an Avatar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final avatar in avatarOptions)
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(_currentUserId!)
                            .update({'avatar': avatar.name});
                        await _loadUserData();
                        if (stateContext.mounted) {
                          ScaffoldMessenger.of(stateContext).showSnackBar(
                            const SnackBar(
                              content: Text('Avatar updated!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          ClipOval(
                            child: Image.network(avatar.url,
                                width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 4),
                          Text(avatar.name,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Maps a saved avatar name back to its hosted image URL.
  String _avatarUrl(String name) {
    for (final avatar in avatarOptions) {
      if (avatar.name == name) return avatar.url;
    }
    return 'https://api.dicebear.com/7.x/adventurer/png?seed=JC&backgroundColor=1B5E20&size=256';
  }

  // Shows the "Change Password" dialog for the signed-in user.
  void _showChangePasswordDialog() {
    final stateContext = context;
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var isWorking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Enter your current password then your new password.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock, size: 18),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New password (min 6)',
                  prefixIcon: const Icon(Icons.password, size: 18),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.password, size: 18),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium)),
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
                if (isWorking) return;
                final current = currentController.text;
                final next = newController.text;
                final confirm = confirmController.text;
                if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fill in all fields'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                if (next != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                if (dialogContext.mounted)
                  setDialogState(() => isWorking = true);
                final result = await _authService.changePassword(
                    currentPassword: current, newPassword: next);
                if (!mounted) return;
                ScaffoldMessenger.of(stateContext).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] as String),
                    backgroundColor: result['success'] == true
                        ? Colors.green
                        : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (result['success'] == true) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
              ),
              child: Text(isWorking ? 'Please wait...' : 'Update Password'),
            ),
          ],
        ),
      ),
    );
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: _userData?['avatar'] != null
                                    ? NetworkImage(
                                        _avatarUrl(
                                            (_userData!['avatar'] as String)))
                                    : null,
                                child: (_userData?['avatar'] == null)
                                    ? Text(
                                        _userData?['fullName'] != null
                                            ? (_userData!['fullName']
                                                    as String)[0]
                                                .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.face_retouching_natural,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getUserTypeLabel(
                                _userData?['userType'] ?? 'guest'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppSizes.fontSmall),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // WALLET BALANCE
                  StreamBuilder<double>(
                    stream: _currentUserId != null
                        ? _walletService.getWalletBalance(_currentUserId!)
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0.0;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8)
                          ],
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
                              child: const Icon(Icons.account_balance_wallet,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Wallet Balance',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: AppSizes.fontSmall)),
                                Text(
                                  '${_formatAmount(balance.toInt())} UGX',
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
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                            (_userData?['badgeCount'] ?? 0).toString(),
                            'Badges',
                            Icons.emoji_events,
                            AppColors.gold),
                        Container(
                            height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatItem(
                            _userData?['userType'] == 'bachelor'
                                ? 'BSc'
                                : _userData?['userType'] == 'diploma'
                                    ? 'Diploma'
                                    : 'Guest',
                            'Account Type',
                            Icons.school,
                            AppColors.primary),
                        Container(
                            height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatItem(
                            _userData?['isVerified'] == true ? 'Yes' : 'No',
                            'Verified',
                            Icons.verified,
                            Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // BADGES
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.emoji_events,
                              color: AppColors.gold, size: 22),
                          SizedBox(width: 8),
                          Text('My Badges',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.fontMedium)),
                        ]),
                        const SizedBox(height: 12),
                        if ((_userData?['badgeCount'] ?? 0) == 0)
                          Text(
                            'No badges yet. Keep participating in tournaments and the community to earn badges!',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: AppSizes.fontSmall),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (int i = 0;
                                  i <
                                      (_userData?['badgeCount'] ?? 0)
                                          .clamp(0, 8);
                                  i++)
                                Container(
                                  width: 76,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.gold),
                                  ),
                                  child: Column(children: [
                                    const Icon(Icons.military_tech,
                                        color: AppColors.gold, size: 26),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Badge ${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ]),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CHANGE PASSWORD
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.password),
                      label: const Text('Change Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMedium)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // LOGOUT
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _authService.logout();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(
                              context, '/onboarding');
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMedium)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontMedium,
                color: color)),
        Text(label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'bachelor':
        return 'Bachelor Student';
      case 'diploma':
        return 'Diploma Student';
      case 'admin':
        return 'Administrator';
      default:
        return 'Community Guest';
    }
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]!},');
  }
}
