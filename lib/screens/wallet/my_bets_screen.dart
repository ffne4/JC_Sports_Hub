import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/bet_model.dart';
import '../../services/betting_service.dart';
import '../../utils/constants.dart';

// Shows every bet the user has placed: what they staked, what selection
// they backed, and what they stand to win. This is where "the user
// should see what he has bet and the amount he expects to win" lives.
class MyBetsScreen extends StatelessWidget {
  const MyBetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final BettingService bettingService = BettingService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('My Bets', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to view your bets'))
          : StreamBuilder<List<BetModel>>(
              stream: bettingService.getMyBets(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final bets = snapshot.data ?? [];

                if (bets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "You haven't placed any bets yet",
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bets.length,
                  itemBuilder: (context, index) => _buildBetCard(bets[index]),
                );
              },
            ),
    );
  }

  Widget _buildBetCard(BetModel bet) {
    Color statusColor;
    String statusLabel;
    switch (bet.status) {
      case BetStatus.won:
        statusColor = Colors.green;
        statusLabel = 'WON';
        break;
      case BetStatus.lost:
        statusColor = AppColors.error;
        statusLabel = 'LOST';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bet.matchLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statColumn('Your Pick', 'Team ${bet.selection}'),
              ),
              Expanded(
                child: _statColumn('Staked', 'UGX ${bet.stakeAmount.toInt()}'),
              ),
              Expanded(
                child: _statColumn(
                  bet.status == BetStatus.won ? 'Won' : 'Potential Win',
                  'UGX ${bet.potentialWinnings.toInt()}',
                  valueColor: bet.status == BetStatus.won
                      ? Colors.green
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.fontSmall,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
