import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/constants.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'my_bets_screen.dart';

// The user's wallet home screen - shows their live balance and gives
// access to deposit, withdraw and their bet history. Same visual style
// as match_detail_screen.dart (rounded green header, white content cards).
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final WalletService walletService = WalletService();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('My Wallet', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: Text('Please log in to view your wallet')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'My Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // BALANCE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                        color: Colors.white70, fontSize: AppSizes.fontMedium),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<double>(
                    stream: walletService.getWalletBalance(userId),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0.0;
                      return Text(
                        'UGX ${balance.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  StreamBuilder<double>(
                    stream: walletService.getPendingWithdrawalAmount(userId),
                    builder: (context, snapshot) {
                      final pending = snapshot.data ?? 0.0;
                      if (pending <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'UGX ${pending.toInt()} pending withdrawal',
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: AppSizes.fontSmall),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DepositScreen()),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Deposit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WithdrawScreen()),
                          ),
                          icon: const Icon(Icons.arrow_circle_up_outlined),
                          label: const Text('Withdraw'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // MY BETS SHORTCUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.receipt_long, color: AppColors.primary),
                  title: const Text('My Bets',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'See what you\'ve staked and what you could win'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBetsScreen()),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // TRANSACTION HISTORY
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontMedium),
                ),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<WalletTransactionModel>>(
              stream: walletService.getMyTransactions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: transactions
                        .map((txn) => _buildTransactionTile(txn))
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel txn) {
    final bool isDeposit = txn.type == TransactionType.deposit;
    final Color statusColor = txn.status == TransactionStatus.confirmed
        ? Colors.green
        : txn.status == TransactionStatus.rejected
            ? AppColors.error
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isDeposit ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeposit ? 'Deposit' : 'Withdrawal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'UGX ${txn.amount.toInt()}',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppSizes.fontSmall),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              txn.status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
