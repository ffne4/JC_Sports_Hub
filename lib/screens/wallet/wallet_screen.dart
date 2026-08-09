import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/constants.dart';
import '../bets/bets_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WalletService _walletService = WalletService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _userData;
  Map<String, int>? _betSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    await _loadBetSummary();
  }

  Future<void> _loadBetSummary() async {
    if (_currentUserId == null) return;
    final summary = await _walletService.getUserBetSummary(_currentUserId!);
    if (mounted) {
      setState(() => _betSummary = summary);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Balance'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBalanceTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildBalanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // BALANCE CARD
          StreamBuilder<int>(
            stream: _currentUserId != null
                ? _walletService.getBalanceStream(_currentUserId!)
                : const Stream.empty(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _userData?['fullName'] ?? 'My Wallet',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatAmount(balance)} UGX',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add Funds',
                  color: AppColors.primary,
                  onTap: _showDepositDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.arrow_circle_up,
                  label: 'Withdraw',
                  color: Colors.orange,
                  onTap: _showWithdrawDialog,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // BET SUMMARY
          if (_betSummary != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BetsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Bets',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.fontSmall,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_betSummary!['active']} active | ${_betSummary!['won']} won | ${_betSummary!['lost']} lost',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // HOW IT WORKS
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How it works',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHowItWorksStep(
                  '1',
                  'Add Funds',
                  'Deposit via MTN MoMo to your wallet',
                  Icons.add,
                ),
                _buildHowItWorksStep(
                  '2',
                  'Place Bets',
                  'Bet on match outcomes using your balance',
                  Icons.sports_soccer,
                ),
                _buildHowItWorksStep(
                  '3',
                  'Win & Withdraw',
                  'Winnings go to your wallet, withdraw anytime',
                  Icons.emoji_events,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(
      String number, String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSmall,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontSmall,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_currentUserId == null) {
      return const Center(child: Text('Please log in to view history'));
    }

    return StreamBuilder<List<WalletTransaction>>(
      stream: _walletService.getTransactionHistory(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add funds to get started',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: AppSizes.fontSmall,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            return _buildTransactionCard(transactions[index]);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(WalletTransaction tx) {
    // Determine icon and color based on transaction type
    IconData icon;
    Color color;
    String sign;

    switch (tx.type) {
      case TransactionType.deposit:
        icon = Icons.arrow_circle_down;
        color = Colors.green;
        sign = '+';
        break;
      case TransactionType.bet:
        icon = Icons.sports_soccer;
        color = Colors.orange;
        sign = '-';
        break;
      case TransactionType.winnings:
        icon = Icons.emoji_events;
        color = AppColors.gold;
        sign = '+';
        break;
      case TransactionType.withdrawal:
        icon = Icons.arrow_circle_up;
        color = Colors.red;
        sign = '-';
        break;
      default:
        icon = Icons.swap_horiz;
        color = Colors.grey;
        sign = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontSmall,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getStatusColor(tx.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: _getStatusColor(tx.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx.reference,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '$sign${_formatAmount(tx.amount)} UGX',
            style: TextStyle(
              color: sign == '+' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: AppSizes.fontSmall,
            ),
          ),
        ],
      ),
    );
  }

  // DEPOSIT DIALOG - shows step by step payment instructions
  void _showDepositDialog() {
    final amountController = TextEditingController();
    final momoController = TextEditingController();
    String? generatedReference;
    bool showInstructions = false;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Add Funds',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minimum deposit: ${WalletService.minimumDeposit} UGX',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: AppSizes.fontSmall,
                  ),
                ),
                const SizedBox(height: 20),

                if (!showInstructions) ...[
                  // STEP 1 - Enter details
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (UGX)',
                      hintText: 'e.g. 5000',
                      prefixIcon:
                          const Icon(Icons.money, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: momoController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Your MTN MoMo Number',
                      hintText: 'e.g. 0771234567',
                      prefixIcon:
                          const Icon(Icons.phone, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final amount =
                                  int.tryParse(amountController.text) ?? 0;
                              if (amount < WalletService.minimumDeposit) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Minimum deposit is ${WalletService.minimumDeposit} UGX'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              if (momoController.text.trim().length < 10) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid MoMo number'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isLoading = true);

                              final result =
                                  await _walletService.createDepositRequest(
                                userId: _currentUserId!,
                                userName: _userData?['fullName'] ?? 'User',
                                userMomoNumber: momoController.text.trim(),
                                amount: amount,
                              );

                              setModalState(() {
                                isLoading = false;
                                if (result['success']) {
                                  generatedReference = result['reference'];
                                  showInstructions = true;
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Get Payment Instructions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ] else ...[
                  // STEP 2 - Payment instructions
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Deposit request created!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Follow these steps to complete payment:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Step by step instructions
                        _instructionStep(
                            '1', 'Open your MTN MoMo app or dial *165#'),
                        _instructionStep('2', 'Select "Send Money"'),
                        _instructionStep('3',
                            'Enter recipient number: ${WalletService.adminMomoNumber}'),
                        _instructionStep(
                            '4', 'Enter amount: ${amountController.text} UGX'),
                        _instructionStep('5',
                            'In the REASON/REFERENCE field, type exactly:'),

                        // Reference code - copyable
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                generatedReference ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.fontLarge,
                                  letterSpacing: 2,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: generatedReference ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reference copied!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),

                        _instructionStep(
                            '6', 'Confirm payment with your MoMo PIN'),
                        _instructionStep(
                            '7', 'Come back here and tap "I\'ve Paid" below'),

                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 4),

                        // Recipient info
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Sending to: ${WalletService.adminMomoName} (${WalletService.adminMomoNumber})',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: AppSizes.fontSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // I've Paid button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Payment noted! Your wallet will be credited after admin verifies. This usually takes a few minutes.',
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("I've Paid"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: AppSizes.fontSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WITHDRAW DIALOG
  void _showWithdrawDialog() async {
    final amountController = TextEditingController();
    final momoController = TextEditingController();
    int currentBalance = await _walletService.getBalance(_currentUserId!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Withdraw Funds',
              style: TextStyle(
                fontSize: AppSizes.fontLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${_formatAmount(currentBalance)} UGX',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                hintText: 'Min 1,000 UGX',
                prefixIcon: const Icon(Icons.money, color: AppColors.primary),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: momoController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Your MTN MoMo Number',
                hintText: 'Number to receive payment',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text) ?? 0;
                  final momo = momoController.text.trim();

                  if (amount < 1000 || momo.length < 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter valid amount and MoMo number'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  final result = await _walletService.requestWithdrawal(
                    userId: _currentUserId!,
                    userName: _userData?['fullName'] ?? 'User',
                    userMomoNumber: momo,
                    amount: amount,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']),
                        backgroundColor:
                            result['success'] ? Colors.green : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: const Text(
                  'Request Withdrawal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case TransactionStatus.confirmed:
        return Colors.green;
      case TransactionStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatAmount(int amount) {
    // Format with commas e.g. 10000 -> 10,000
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
