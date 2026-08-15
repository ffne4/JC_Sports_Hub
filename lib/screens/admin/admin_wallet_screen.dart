import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/match_model.dart';
import '../../models/match_betting_model.dart';
import '../../models/wallet_model.dart';
import '../../services/match_service.dart';
import '../../services/wallet_service.dart';
import '../../services/betting_service.dart';
import '../../utils/constants.dart';

// Admin screen for everything money-related: confirming deposits,
// confirming/paying withdrawals, and managing betting on each match
// (opening it with odds, manually ending it if it stalled, and settling
// it to pay out winners). Reached from a new tab in AdminPanelScreen.
class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WalletService _walletService = WalletService();
  // Cached once - re-creating these Firestore streams on every rebuild
  // re-subscribes and can freeze the admin panel.
  late final Stream<List<WalletTransactionModel>> _pendingDepositsStream =
      _walletService.getPendingDeposits();
  late final Stream<List<WalletTransactionModel>> _pendingWithdrawalsStream =
      _walletService.getPendingWithdrawals();

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

  String get _adminId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        title: const Text('Wallet & Betting',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Deposits'),
            Tab(text: 'Withdrawals'),
            Tab(text: 'Betting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDepositsTab(),
          _buildWithdrawalsTab(),
          const _BettingManagementTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DEPOSITS TAB
  // ---------------------------------------------------------------------
  Widget _buildDepositsTab() {
    return StreamBuilder<List<WalletTransactionModel>>(
      stream: _pendingDepositsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final deposits = snapshot.data ?? [];
        if (deposits.isEmpty) {
          return _emptyState('No pending deposits', Icons.check_circle_outline);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deposits.length,
          itemBuilder: (context, index) {
            final txn = deposits[index];
            return _pendingTransactionCard(
              title: txn.userName,
              amountLabel: 'UGX ${txn.amount.toInt()}',
              subtitle: 'From ${txn.momoNumber ?? '—'} · Ref: ${txn.reference ?? '—'}',
              onConfirm: () async {
                final result = await _walletService.confirmDeposit(
                  transactionId: txn.id,
                  adminId: _adminId,
                );
                _showResult(result);
              },
              onReject: () async {
                final result = await _walletService.rejectDeposit(
                  transactionId: txn.id,
                  adminId: _adminId,
                );
                _showResult(result);
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // WITHDRAWALS TAB
  // ---------------------------------------------------------------------
  Widget _buildWithdrawalsTab() {
    return StreamBuilder<List<WalletTransactionModel>>(
      stream: _pendingWithdrawalsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final withdrawals = snapshot.data ?? [];
        if (withdrawals.isEmpty) {
          return _emptyState(
              'No pending withdrawals', Icons.check_circle_outline);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: withdrawals.length,
          itemBuilder: (context, index) {
            final txn = withdrawals[index];
            return _pendingTransactionCard(
              title: txn.userName,
              amountLabel: 'Requested UGX ${txn.amount.toInt()}',
              subtitle:
                  'Send UGX ${(txn.netAmountToSend ?? txn.amount).toInt()} to ${txn.momoNumber ?? '—'} (after 12% charge)',
              highlightSubtitle: true,
              onConfirm: () async {
                final result = await _walletService.confirmWithdrawal(
                  transactionId: txn.id,
                  adminId: _adminId,
                );
                _showResult(result);
              },
              onReject: () async {
                final result = await _walletService.rejectWithdrawal(
                  transactionId: txn.id,
                  adminId: _adminId,
                );
                _showResult(result);
              },
            );
          },
        );
      },
    );
  }

  void _showResult(Map<String, dynamic> result) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: AppSizes.fontMedium, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _pendingTransactionCard({
    required String title,
    required String amountLabel,
    required String subtitle,
    required Future<void> Function() onConfirm,
    required Future<void> Function() onReject,
    bool highlightSubtitle = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(amountLabel,
              style: const TextStyle(
                  fontSize: AppSizes.fontMedium, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppSizes.fontSmall,
              color:
                  highlightSubtitle ? AppColors.primary : Colors.grey.shade600,
              fontWeight:
                  highlightSubtitle ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// BETTING MANAGEMENT TAB
// ---------------------------------------------------------------------
// Lists every match and, per match, shows the right action for whatever
// state its betting is in: not opened yet -> set odds; open -> end it
// (this is the previously-missing "admin ends a stuck match" feature);
// ended -> pick the winner and settle to pay everyone out.
class _BettingManagementTab extends StatefulWidget {
  const _BettingManagementTab();

  @override
  State<_BettingManagementTab> createState() => _BettingManagementTabState();
}

class _BettingManagementTabState extends State<_BettingManagementTab> {
  final MatchService _matchService = MatchService();
  late final Stream<List<MatchModel>> _matchesStream =
      _matchService.getAllMatches();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return Center(
            child: Text('No matches yet',
                style: TextStyle(color: Colors.grey.shade500)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) =>
              _MatchBettingCard(match: matches[index]),
        );
      },
    );
  }
}

class _MatchBettingCard extends StatefulWidget {
  final MatchModel match;
  const _MatchBettingCard({required this.match});

  @override
  State<_MatchBettingCard> createState() => _MatchBettingCardState();
}

class _MatchBettingCardState extends State<_MatchBettingCard> {
  final BettingService _bettingService = BettingService();
  final TextEditingController _oddsAController =
      TextEditingController(text: '2.0');
  final TextEditingController _oddsBController =
      TextEditingController(text: '2.0');
  String _selectedWinner = 'A';
  bool _isWorking = false;
  late final Stream<MatchBettingModel?> _bettingStream =
      _bettingService.getMatchBetting(widget.match.id);

  @override
  void dispose() {
    _oddsAController.dispose();
    _oddsBController.dispose();
    super.dispose();
  }

  void _showResult(Map<String, dynamic> result) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchBettingModel?>(
      stream: _bettingStream,
      builder: (context, snapshot) {
        final betting = snapshot.data;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.match.teamA} vs ${widget.match.teamB}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                betting == null
                    ? 'Betting not opened yet'
                    : 'Betting: ${betting.status.toUpperCase()}',
                style: TextStyle(
                    fontSize: AppSizes.fontSmall, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              if (betting == null) _buildOpenBettingForm(),
              if (betting != null && betting.status == BettingStatus.open)
                _buildEndBettingButton(),
              if (betting != null && betting.status == BettingStatus.ended)
                _buildSettleForm(),
              if (betting != null && betting.status == BettingStatus.settled)
                Text(
                  'Settled - Winner: Team ${betting.winningSelection}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpenBettingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _oddsAController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${widget.match.teamA} odds',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _oddsBController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${widget.match.teamB} odds',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isWorking
                ? null
                : () async {
                    setState(() => _isWorking = true);
                    final result = await _bettingService.openBetting(
                      matchId: widget.match.id,
                      oddsA: double.tryParse(_oddsAController.text) ?? 2.0,
                      oddsB: double.tryParse(_oddsBController.text) ?? 2.0,
                    );
                    setState(() => _isWorking = false);
                    _showResult(result);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Betting'),
          ),
        ),
      ],
    );
  }

  Widget _buildEndBettingButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isWorking
            ? null
            : () async {
                setState(() => _isWorking = true);
                final result = await _bettingService.endMatchBetting(
                    matchId: widget.match.id);
                setState(() => _isWorking = false);
                _showResult(result);
              },
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('End Betting'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
      ),
    );
  }

  Widget _buildSettleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who won?', style: TextStyle(fontSize: AppSizes.fontSmall)),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    Text(widget.match.teamA, overflow: TextOverflow.ellipsis),
                value: 'A',
                groupValue: _selectedWinner,
                onChanged: (val) =>
                    setState(() => _selectedWinner = val ?? 'A'),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    Text(widget.match.teamB, overflow: TextOverflow.ellipsis),
                value: 'B',
                groupValue: _selectedWinner,
                onChanged: (val) =>
                    setState(() => _selectedWinner = val ?? 'A'),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isWorking
                ? null
                : () async {
                    setState(() => _isWorking = true);
                    final result = await _bettingService.settleMatch(
                      matchId: widget.match.id,
                      winningSelection: _selectedWinner,
                    );
                    setState(() => _isWorking = false);
                    _showResult(result);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Settle & Pay Out'),
          ),
        ),
      ],
    );
  }
}
