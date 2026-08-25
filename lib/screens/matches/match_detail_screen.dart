import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/match_model.dart';
import '../../models/match_betting_model.dart';
import '../../services/betting_service.dart';
import '../../utils/constants.dart';

// NOTE: this screen was converted from StatelessWidget to StatefulWidget
// so the new "Place a Bet" section at the bottom could hold its own
// input state (stake amount, selected team). Every line of the existing
// score card / predictions / admin notes sections below is unchanged -
// it has just moved inside a State class's build() method, and widget.match
// is used instead of this.match, which Dart requires for that move.
class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final BettingService _bettingService = BettingService();
  final TextEditingController _stakeController = TextEditingController();
  String _selectedTeam = 'A';
  bool _isPlacingBet = false;

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final int totalVotes = match.votesA + match.votesB;
    final double percentA = totalVotes > 0 ? match.votesA / totalVotes : 0.5;
    final double percentB = totalVotes > 0 ? match.votesB / totalVotes : 0.5;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          '${match.teamA} vs ${match.teamB}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontMedium,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // SCORE CARD
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
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      match.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Team A
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              match.teamA.isNotEmpty
                                  ? match.teamA[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match.teamA,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Score
                      match.status == MatchStatus.upcoming
                          ? Column(
                              children: [
                                const Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatFullDate(match.matchDate),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: AppSizes.fontSmall,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '${match.scoreA}  -  ${match.scoreB}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),

                      // Team B
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              match.teamB.isNotEmpty
                                  ? match.teamB[0].toUpperCase()
                                  : 'B',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match.teamB,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Venue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        match.venue,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: AppSizes.fontSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PREDICTIONS SECTION
            if (totalVotes > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Community Predictions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            match.teamA,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSmall,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            match.teamB,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSmall,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percentA,
                          backgroundColor: Colors.orange.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                          minHeight: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${(percentA * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(percentB * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          '$totalVotes total predictions',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ADMIN NOTES
            if (match.adminNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Admin Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.fontMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        match.adminNotes,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSmall,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // PLACE A BET SECTION (new - additive, doesn't touch anything above)
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBettingSection(match),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Streams the match's betting status/odds and shows whichever UI fits:
  // nothing if betting was never opened, a bet-placement form if open,
  // or a simple "betting closed" notice otherwise.
  Widget _buildBettingSection(MatchModel match) {
    return StreamBuilder<MatchBettingModel?>(
      stream: _bettingService.getMatchBetting(match.id),
      builder: (context, snapshot) {
        final betting = snapshot.data;

        // Betting is only available on UPCOMING matches - never on live or
        // completed ones.
        if (match.status != MatchStatus.upcoming) {
          return const SizedBox.shrink();
        }

        if (betting == null) {
          // Betting hasn't been opened by an admin for this match yet -
          // show nothing rather than an empty/confusing card.
          return const SizedBox.shrink();
        }

        return Container(
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
                  Icon(Icons.sports_score, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Place a Bet',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (betting.status != BettingStatus.open)
                Text(
                  betting.status == BettingStatus.settled
                      ? 'Betting has closed. Winner: Team ${betting.winningSelection}'
                      : 'Betting has closed for this match.',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppSizes.fontSmall),
                )
              else ...[
                // Team selector
                Row(
                  children: [
                    Expanded(
                      child: _teamOddsButton(
                        label: match.teamA,
                        odds: betting.oddsA,
                        selected: _selectedTeam == 'A',
                        onTap: () => setState(() => _selectedTeam = 'A'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _teamOddsButton(
                        label: match.teamB,
                        odds: betting.oddsB,
                        selected: _selectedTeam == 'B',
                        onTap: () => setState(() => _selectedTeam = 'B'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _stakeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Stake amount (UGX)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPotentialWinningsPreview(betting),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed:
                        _isPlacingBet ? null : () => _placeBet(match, betting),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                    child: _isPlacingBet
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Place Bet'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _teamOddsButton({
    required String label,
    required double odds,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(color: AppColors.primary, width: selected ? 0 : 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontSmall,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            Text(
              'x$odds',
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Colors.white70
                    : AppColors.primary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "the user should see... the amount he expects to win from the bet" -
  // this preview updates live as they type, before they even submit.
  Widget _buildPotentialWinningsPreview(MatchBettingModel betting) {
    final double stake = double.tryParse(_stakeController.text.trim()) ?? 0;
    final double odds = _selectedTeam == 'A' ? betting.oddsA : betting.oddsB;
    final double potentialWinnings = stake * odds;

    if (stake <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            'You could win UGX ${potentialWinnings.toInt()}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: AppSizes.fontSmall),
          ),
        ],
      ),
    );
  }

  Future<void> _placeBet(MatchModel match, MatchBettingModel betting) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to place a bet'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double? stake = double.tryParse(_stakeController.text.trim());
    if (stake == null || stake <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid stake amount'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isPlacingBet = true);

    final result = await _bettingService.placeBet(
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'User',
      matchId: match.id,
      matchLabel: '${match.teamA} vs ${match.teamB}',
      selection: _selectedTeam,
      stakeAmount: stake,
    );

    if (mounted) {
      setState(() => _isPlacingBet = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? AppColors.accent : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result['success']) {
        _stakeController.clear();
      }
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute';
  }
}
