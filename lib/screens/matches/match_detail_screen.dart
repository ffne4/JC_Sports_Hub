import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/match_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../bets/bets_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final WalletService _walletService = WalletService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _betAmount = 0;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final totalVotes = match.votesA + match.votesB;
    final percentA = totalVotes > 0 ? match.votesA / totalVotes : 0.5;
    final percentB = totalVotes > 0 ? match.votesB / totalVotes : 0.5;

    final bool hasVoted = _currentUserId != null && match.votedBy.contains(_currentUserId);
    Map<String, dynamic>? userBet;
    if (hasVoted && _currentUserId != null && match.bets.containsKey(_currentUserId)) {
      userBet = match.bets[_currentUserId] as Map<String, dynamic>?;
    }

    final bool isLive = match.status == MatchStatus.live;
    final bool isUpcoming = match.status == MatchStatus.upcoming;
    final bool isCompleted = match.status == MatchStatus.completed || match.status == MatchStatus.cancelled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          '${match.teamA} vs ${match.teamB}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero score/status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      match.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSmall,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TeamColumn(name: match.teamA, color: AppColors.primary),
                      _ScoreCenter(match: match),
                      _TeamColumn(name: match.teamB, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        match.venue,
                        style: const TextStyle(color: Colors.white70, fontSize: AppSizes.fontSmall),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status-specific sections
            if (isUpcoming && !hasVoted && _currentUserId != null)
              _buildBettingSection(match),
            if (isUpcoming && hasVoted && userBet != null)
              _buildUserBetSummary(userBet, match),

            if (isLive)
              _buildLiveSection(match, userBet),

            if (isCompleted)
              _buildCompletedSection(match, userBet),

            // Predictions
            if (totalVotes > 0)
              _buildPredictionsSection(match, totalVotes, percentA, percentB),

            // Admin notes
            if (match.adminNotes.isNotEmpty)
              _buildAdminNotesSection(match.adminNotes),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBettingSection(MatchModel match) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Place Your Bet',
                      style: TextStyle(
                        fontSize: AppSizes.fontMedium,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showBetDialog(context, match, 'A'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(match.teamA, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              '${match.oddsA.toStringAsFixed(2)}x',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showBetDialog(context, match, 'B'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(match.teamB, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              '${match.oddsB.toStringAsFixed(2)}x',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBetSummary(Map<String, dynamic> userBet, MatchModel match) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bet placed on ${userBet['teamName'] ?? match.teamA}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCurrency(userBet['amount'] as int? ?? 0)} UGX at ${(userBet['oddsAtPlacement'] ?? 1.5).toStringAsFixed(2)}x | Potential win: ${formatCurrency(userBet['potentialWinnings'] as int? ?? 0)} UGX',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSection(MatchModel match, Map<String, dynamic>? userBet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Match in progress — betting is closed',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (userBet != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your bet: ${formatCurrency(userBet['amount'] as int? ?? 0)} UGX on ${userBet['teamName'] ?? ''} | Win: ${formatCurrency(userBet['potentialWinnings'] as int? ?? 0)} UGX',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedSection(MatchModel match, Map<String, dynamic>? userBet) {
    final settled = match.winnersDistributed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: settled ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              border: Border.all(
                color: settled ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  settled ? Icons.emoji_events : Icons.hourglass_bottom,
                  color: settled ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settled ? 'Match settled — winnings distributed' : 'Awaiting winnings distribution by admin',
                    style: TextStyle(
                      color: settled ? Colors.green : Colors.orange,
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (userBet != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your bet: ${formatCurrency(userBet['amount'] as int? ?? 0)} UGX on ${userBet['teamName'] ?? ''} at ${(userBet['oddsAtPlacement'] ?? 1.5).toStringAsFixed(2)}x',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPredictionsSection(MatchModel match, int totalVotes, double percentA, double percentB) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.show_chart, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Community Predictions',
                  style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(match.teamA, style: const TextStyle(fontSize: AppSizes.fontSmall, color: AppColors.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(match.teamB, style: const TextStyle(fontSize: AppSizes.fontSmall, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentA,
                backgroundColor: Colors.orange.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${(percentA * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$totalVotes bets', style: TextStyle(color: Colors.grey.shade500, fontSize: AppSizes.fontSmall)),
                const Spacer(),
                Text('${(percentB * 100).toInt()}%', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Total Pool: ${formatCurrency(match.totalPool)} UGX',
                style: TextStyle(color: Colors.grey.shade400, fontSize: AppSizes.fontSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNotesSection(String adminNotes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Text(
                  'Admin Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontMedium,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              adminNotes,
              style: const TextStyle(fontSize: AppSizes.fontSmall, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showBetDialog(BuildContext context, MatchModel match, String team) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to place a bet'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data() as Map<String, dynamic>;
    if (userData['userType'] == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Create a student account to place bets. Guests can only watch.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    final total = (userData['walletBalance'] ?? 0) as int;
    final locked = (userData['lockedBalance'] ?? 0) as int;
    final balance = total - locked;
    final userName = userData['fullName'] ?? 'User';
    final userMomoNumber = userData['momoNumber'] ?? '';
    final teamName = team == 'A' ? match.teamA : match.teamB;
    final odds = team == 'A' ? match.oddsA : match.oddsB;

    if (balance < WalletService.minimumBet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Insufficient balance. Minimum bet is ${WalletService.minimumBet} UGX.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    final betController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
        title: Text('Bet on $teamName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${formatCurrency(balance)} UGX',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Odds for $teamName', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      Text('${odds.toStringAsFixed(2)}x',
                          style: const TextStyle(color: AppColors.primary, fontSize: AppSizes.fontLarge, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.trending_up, color: AppColors.primary, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Example: 1000 UGX × ${odds.toStringAsFixed(2)} = ${formatCurrency((1000 * odds).floor())} UGX if you win',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
             const SizedBox(height: 12),
             TextField(
               controller: betController,
               keyboardType: TextInputType.number,
               autofocus: true,
               onChanged: (val) {
                 final parsed = int.tryParse(val) ?? 0;
                 setState(() {
                   _betAmount = parsed > 0 ? parsed : 0;
                 });
               },
               decoration: InputDecoration(
                 labelText: 'Bet Amount (UGX)',
                 hintText: 'Min ${WalletService.minimumBet} UGX',
                 prefixIcon: const Icon(Icons.money, color: AppColors.primary),
                 filled: true,
                 fillColor: Colors.grey.shade50,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                   borderSide: const BorderSide(color: AppColors.primary, width: 2),
                 ),
               ),
             ),
             if (_betAmount > 0)
               Container(
                 margin: const EdgeInsets.only(top: 10),
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: AppColors.accent.withOpacity(0.08),
                   borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                   border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('Expected Return', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                     Text(
                       '${formatCurrency((_betAmount * odds).floor())} UGX',
                       style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                     ),
                   ],
                 ),
               ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(betController.text) ?? 0;

              if (amount < WalletService.minimumBet) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Minimum bet is ${WalletService.minimumBet} UGX'),
                  backgroundColor: AppColors.error,
                ));
                return;
              }
              if (amount > WalletService.maximumBet) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Maximum bet is ${formatCurrency(WalletService.maximumBet)} UGX'),
                  backgroundColor: AppColors.error,
                ));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Amount exceeds your available balance'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }

              Navigator.pop(context);

              final result = await _walletService.placeBet(
                userId: _currentUserId!,
                userName: userName,
                userMomoNumber: userMomoNumber,
                matchId: match.id,
                matchName: '${match.teamA} vs ${match.teamB}',
                betTeam: team,
                betTeamName: teamName,
                amount: amount,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['success']
                      ? 'Bet placed! ${formatCurrency(amount)} UGX deducted. If $teamName wins you get ${formatCurrency((amount * odds).floor())} UGX\nRef: ${result['reference'] ?? ''}'
                      : result['message']),
                  backgroundColor: result['success'] ? Colors.green : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                ));

                if (result['success'] == true) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const BetsScreen()),
                      );
                    }
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
            ),
            child: const Text('Place Bet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final Color color;
  const _TeamColumn({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 100,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppSizes.fontSmall),
          ),
        ),
      ],
    );
  }
}

class _ScoreCenter extends StatelessWidget {
  final MatchModel match;
  const _ScoreCenter({required this.match});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = match.status == MatchStatus.upcoming;
    final isLive = match.status == MatchStatus.live;

    if (isUpcoming) {
      return Column(
        children: [
          const Text('VS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: AppSizes.fontSmall),
          ),
          const SizedBox(height: 2),
          Text(
            '${match.matchDate.hour.toString().padLeft(2, '0')}:${match.matchDate.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${match.scoreA}  -  ${match.scoreB}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        if (isLive)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}