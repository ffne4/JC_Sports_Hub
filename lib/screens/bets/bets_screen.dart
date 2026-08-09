import 'package:flutter/material.dart';
import '../../models/bet_model.dart';
import '../../services/bet_service.dart';
import '../../utils/constants.dart';

class BetsScreen extends StatefulWidget {
  const BetsScreen({super.key});

  @override
  State<BetsScreen> createState() => _BetsScreenState();
}

class _BetsScreenState extends State<BetsScreen> with SingleTickerProviderStateMixin {
  final BetService _betService = BetService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text(
          'My Bets',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Won'),
            Tab(text: 'Lost'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBetList(BetStatus.pending),
          _buildBetList(BetStatus.won),
          _buildBetList(BetStatus.lost),
        ],
      ),
    );
  }

  Widget _buildBetList(BetStatus status) {
    return StreamBuilder<List<BetModel>>(
      stream: _betService.getUserBets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final allBets = snapshot.data ?? [];
        final filteredBets = allBets.where((bet) {
          if (status == BetStatus.pending) {
            return bet.status == BetStatus.pending;
          }
          if (status == BetStatus.won) {
            return bet.status == BetStatus.won;
          }
          if (status == BetStatus.lost) {
            return bet.status == BetStatus.lost;
          }
          return false;
        }).toList();

        if (filteredBets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == BetStatus.pending
                      ? Icons.pending_actions_outlined
                      : status == BetStatus.won
                          ? Icons.emoji_events_outlined
                          : Icons.sentiment_dissatisfied_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  status == BetStatus.pending
                      ? 'No active bets'
                      : status == BetStatus.won
                          ? 'No winning bets yet'
                          : 'No lost bets',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status == BetStatus.pending
                      ? 'Place a bet on an upcoming match to see it here'
                      : status == BetStatus.won
                          ? 'Winning bets will appear here after results are posted'
                          : 'Bets will appear here if the result goes against you',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: AppSizes.fontSmall),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBets.length,
          itemBuilder: (context, index) {
            final bet = filteredBets[index];
            return _BetCard(bet: bet);
          },
        );
      },
    );
  }
}

class _BetCard extends StatelessWidget {
  final BetModel bet;

  const _BetCard({required this.bet});

  Color _getStatusColor() {
    switch (bet.status) {
      case BetStatus.won:
        return Colors.green;
      case BetStatus.lost:
        return Colors.red;
      case BetStatus.refunded:
        return Colors.orange;
      case BetStatus.cancelled:
        return Colors.grey;
      case BetStatus.pending:
        return Colors.blue;
    }
  }

  String _getStatusLabel() {
    switch (bet.status) {
      case BetStatus.won:
        return 'WON';
      case BetStatus.lost:
        return 'LOST';
      case BetStatus.refunded:
        return 'REFUNDED';
      case BetStatus.cancelled:
        return 'CANCELLED';
      case BetStatus.pending:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusLabel = _getStatusLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bet.matchName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'On ${bet.betTeamName}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${bet.oddsAtPlacement.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stake',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                    Text(
                      '${bet.amount} UGX',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Potential Win',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                    Text(
                      '${bet.potentialWinnings} UGX',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: bet.status == BetStatus.won
                            ? Colors.green
                            : AppColors.dark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                    Text(
                      '${bet.createdAt.day}/${bet.createdAt.month}/${bet.createdAt.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            if (bet.reference != null) ...[
              const SizedBox(height: 6),
              Text(
                'Ref: ${bet.reference}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
