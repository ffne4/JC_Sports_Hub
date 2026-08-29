import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';

import '../../services/betting_service.dart';
import '../../utils/constants.dart';
import 'match_detail_screen.dart';
import '../bets/bets_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MatchService _matchService = MatchService();
  // Cached once so build() doesn't re-create (and re-subscribe to) the
  // Firestore streams on every rebuild - that pattern can freeze the screen.
  late final Stream<List<MatchModel>> _upcomingStream =
      _matchService.getUpcomingMatches();
  late final Stream<List<MatchModel>> _liveStream =
      _matchService.getLiveMatches();
  late final Stream<List<MatchModel>> _completedStream =
      _matchService.getCompletedMatches();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _betAmount = 0;

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
        automaticallyImplyLeading: false,
        title: const Text('Matches',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Live 🔴'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchList(_upcomingStream, 'upcoming'),
          _buildMatchList(_liveStream, 'live'),
          _buildMatchList(_completedStream, 'completed'),
        ],
      ),
    );
  }

  Widget _buildMatchList(Stream<List<MatchModel>> stream, String type) {
    return StreamBuilder<List<MatchModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  type == 'live'
                      ? 'No live matches right now'
                      : type == 'upcoming'
                          ? 'No upcoming matches scheduled'
                          : 'No completed matches yet',
                  style: TextStyle(
                      fontSize: AppSizes.fontMedium,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) => _buildMatchCard(matches[index]),
        );
      },
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    final bool hasVoted = match.votedBy.contains(_currentUserId);
    final String? userVote =
        _currentUserId != null ? match.userVotes[_currentUserId] : null;
    final int totalVotes = match.votesA + match.votesB;
    final double percentA = totalVotes > 0 ? match.votesA / totalVotes : 0.5;
    final double percentB = totalVotes > 0 ? match.votesB / totalVotes : 0.5;

    // Get user's bet details if they have bet
    Map<String, dynamic>? userBet;
    if (hasVoted &&
        _currentUserId != null &&
        match.bets.containsKey(_currentUserId)) {
      userBet = match.bets[_currentUserId] as Map<String, dynamic>?;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MatchDetailScreen(match: match))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _getStatusColor(match.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusMedium),
                topRight: Radius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: Row(children: [
              Text(_getSportIcon(match.sport),
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(match.sport,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(match.status),
                      fontSize: AppSizes.fontSmall)),
              const Spacer(),
              if (match.status == MatchStatus.live)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _getStatusColor(match.status),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(match.status.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          // TEAMS + SCORE
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      match.teamA.isNotEmpty
                          ? match.teamA[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(match.teamA,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontSmall)),
                  Text('${match.oddsA.toStringAsFixed(2)}x',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: match.status == MatchStatus.upcoming
                      ? Colors.grey.shade100
                      : AppColors.dark,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: match.status == MatchStatus.upcoming
                    ? Column(children: [
                        Text(_formatMatchDate(match.matchDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontSmall)),
                        Text(_formatMatchTime(match.matchDate),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                      ])
                    : Column(children: [
                        Text('${match.scoreA}  -  ${match.scoreB}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontLarge,
                                letterSpacing: 2)),
                        if (match.status == MatchStatus.live)
                          const Text('LIVE',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                      ]),
              ),
              Expanded(
                child: Column(children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    child: Text(
                      match.teamB.isNotEmpty
                          ? match.teamB[0].toUpperCase()
                          : 'B',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(match.teamB,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontSmall)),
                  Text('${match.oddsB.toStringAsFixed(2)}x',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),

          // VENUE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(match.venue,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: AppSizes.fontSmall)),
            ]),
          ),

          const SizedBox(height: 12),

          // COMPLETED MATCH - show winner
          if (match.status == MatchStatus.completed ||
              match.status == MatchStatus.cancelled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                if (match.winnersDistributed) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Match settled',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              if (match.userVotes.containsKey(_currentUserId))
                                Text(
                                  (match.scoreA > match.scoreB &&
                                              match.userVotes[_currentUserId] ==
                                                  'A') ||
                                          (match.scoreB > match.scoreA &&
                                              match.userVotes[_currentUserId] ==
                                                  'B')
                                      ? 'You won! Check your wallet.'
                                      : userBet != null
                                          ? 'Bet: ${_fmtAmt(userBet['amount'] as int? ?? 0)} UGX | Odds: ${(userBet['oddsAtPlacement'] ?? 1.5).toStringAsFixed(2)}x'
                                          : '',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11),
                                ),
                            ]),
                      ),
                    ]),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(children: [
                      Icon(Icons.hourglass_bottom,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Awaiting winnings distribution by admin',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: AppSizes.fontSmall)),
                    ]),
                  ),
                ],
                // Show user's bet summary on completed matches
                if (userBet != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.receipt, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Your bet: ${_fmtAmt(userBet['amount'] as int? ?? 0)} UGX on ${userBet['teamName'] ?? ''} at ${(userBet['oddsAtPlacement'] ?? 1.5).toStringAsFixed(2)}x',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ],

          // LIVE MATCH - show score prominently + user bet
          if (match.status == MatchStatus.live) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('Match in progress — betting is closed',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: AppSizes.fontSmall,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                if (userBet != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.sports_soccer,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Your bet: ${_fmtAmt(userBet['amount'] as int? ?? 0)} UGX on ${userBet['teamName'] ?? ''} | Win: ${_fmtAmt(userBet['potentialWinnings'] as int? ?? 0)} UGX',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ],

          // UPCOMING - betting section
          if (match.status == MatchStatus.upcoming) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasVoted && userBet != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                  'Bet placed on ${userBet['teamName'] ?? (userVote == 'A' ? match.teamA : match.teamB)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: AppSizes.fontSmall),
                                ),
                                Text(
                                  '${_fmtAmt(userBet['amount'] as int? ?? 0)} UGX at ${(userBet['oddsAtPlacement'] ?? 1.5).toStringAsFixed(2)}x | Win: ${_fmtAmt(userBet['potentialWinnings'] as int? ?? 0)} UGX',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11),
                                ),
                              ])),
                        ]),
                      ),
                    ] else if (!hasVoted) ...[
                      Text('Place your bet:',
                          style: TextStyle(
                              fontSize: AppSizes.fontSmall,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _placeBet(match, 'A'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSmall)),
                            ),
                            child: Column(children: [
                              Text(match.teamA,
                                  overflow: TextOverflow.ellipsis),
                              Text('${match.oddsA.toStringAsFixed(2)}x',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _placeBet(match, 'B'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSmall)),
                            ),
                            child: Column(children: [
                              Text(match.teamB,
                                  overflow: TextOverflow.ellipsis),
                              Text('${match.oddsB.toStringAsFixed(2)}x',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ]),
                    ],

                    // Vote percentage bar
                    if (totalVotes > 0) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${(percentA * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentA,
                              backgroundColor: Colors.orange.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(percentB * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '$totalVotes ${totalVotes == 1 ? 'bet' : 'bets'} | Pool: ${_fmtAmt(match.totalPool)} UGX',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ]),
            ),
          ],

          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  void _placeBet(MatchModel match, String team) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to place a bet'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    // Load user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .get();

    if (!userDoc.exists) return;
    if (!mounted) return;

    final userData = userDoc.data() as Map<String, dynamic>;

    // Block guests from betting
    if (userData['userType'] == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Create a student account to place bets. Guests can only watch.'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final int total = (userData['walletBalance'] ?? 0) as int;
    final int locked = (userData['lockedBalance'] ?? 0) as int;
    final int balance = total - locked;
    final String userName = userData['fullName'] ?? 'User';
    final String teamName = team == 'A' ? match.teamA : match.teamB;
    final double odds = team == 'A' ? match.oddsA : match.oddsB;

    if (balance < BettingService.minimumBet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Insufficient balance. Need at least ${BettingService.minimumBet} UGX. Add funds in Wallet tab.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    final betController = TextEditingController();
    final outerContext = context;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
        title: Text('Bet on $teamName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${_fmtAmt(balance)} UGX',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Show admin-set odds
            Container(
              padding: const EdgeInsets.all(10),
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
                          Text('Odds for $teamName',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 11)),
                          Text('${odds.toStringAsFixed(2)}x',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: AppSizes.fontLarge,
                                  fontWeight: FontWeight.bold)),
                        ]),
                    const Icon(Icons.trending_up,
                        color: AppColors.primary, size: 24),
                  ]),
            ),
            const SizedBox(height: 4),
            Text(
                'Example: 1000 UGX × ${odds.toStringAsFixed(2)} = ${_fmtAmt((1000 * odds).floor())} UGX if you win',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
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
                hintText: 'Min ${BettingService.minimumBet} UGX',
                prefixIcon: const Icon(Icons.money, color: AppColors.primary),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
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
                    Text('Expected Return',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    Text(
                      '${_fmtAmt((_betAmount * odds).floor())} UGX',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(betController.text) ?? 0;

              if (amount < BettingService.minimumBet) {
                ScaffoldMessenger.of(outerContext).showSnackBar(const SnackBar(
                  content:
                      Text('Minimum bet is ${BettingService.minimumBet} UGX'),
                  backgroundColor: AppColors.error,
                ));
                return;
              }
              if (amount > BettingService.maximumBet) {
                ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(
                  content: Text(
                      'Maximum bet is ${_fmtAmt(BettingService.maximumBet)} UGX'),
                  backgroundColor: AppColors.error,
                ));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(outerContext).showSnackBar(const SnackBar(
                  content: Text('Amount exceeds your available balance'),
                  backgroundColor: AppColors.error,
                ));
                return;
              }

              Navigator.pop(context);

              final potentialWin = (amount * odds).floor();

              final result = await BettingService().placeBet(
                userId: _currentUserId!,
                userName: userName,
                matchId: match.id,
                matchLabel: '${match.teamA} vs ${match.teamB}',
                selection: team,
                stakeAmount: amount.toDouble(),
              );

              if (mounted) {
                ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(
                  content: Text(result['success']
                      ? 'Bet placed! ${_fmtAmt(amount)} UGX deducted. If $teamName wins you get ${_fmtAmt(potentialWin)} UGX'
                      : result['message']),
                  backgroundColor:
                      result['success'] ? AppColors.accent : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ));

                if (result['success'] == true) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        outerContext,
                        MaterialPageRoute(
                            builder: (context) => const BetsScreen()),
                      );
                    }
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
            ),
            child:
                const Text('Place Bet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _fmtAmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Color _getStatusColor(String status) {
    switch (status) {
      case MatchStatus.live:
        return Colors.red;
      case MatchStatus.completed:
        return Colors.grey;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return AppColors.primary;
    }
  }

  String _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'volleyball':
        return '🏐';
      case 'athletics':
        return '🏃';
      default:
        return '🏆';
    }
  }

  String _formatMatchDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatMatchTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

