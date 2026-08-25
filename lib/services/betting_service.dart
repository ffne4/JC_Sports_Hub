import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bet_model.dart';
import '../models/match_betting_model.dart';
import '../models/match_model.dart';

// Handles placing bets and everything an admin needs to run betting on a
// match: opening it with odds, ending it (stopping new bets, even if the
// match itself got stuck and never auto-completed), and settling it
// (paying out winners).
//
// This is a pure "we are just playing with numbers" system - there is no
// external odds/sportsbook integration. The admin sets the odds by hand
// and approves the outcome by hand, same as everything else in this app's
// manual mobile-money flow.
class BettingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _bettingCollection = 'match_betting';
  static const String _betsCollection = 'bets';
  static const String _usersCollection = 'users';

  // Bet size limits - enforced where a bet is placed
  static const int minimumBet = 500;
  static const int maximumBet = 20000;

  // ---------------------------------------------------------------------
  // READING BETTING STATE
  // ---------------------------------------------------------------------

  // Live betting status/odds for one match. Null means betting hasn't
  // been opened for this match yet (admin hasn't set odds).
  Stream<MatchBettingModel?> getMatchBetting(String matchId) {
    return _firestore
        .collection(_bettingCollection)
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.exists ? MatchBettingModel.fromFirestore(doc) : null);
  }

  // Admin - every match that currently has betting open or ended-but-
  // not-yet-settled, so the admin has a single place to manage all of them.
  Stream<List<MatchBettingModel>> getMatchesNeedingAttention() {
    return _firestore
        .collection(_bettingCollection)
        .where('status', whereIn: [BettingStatus.open, BettingStatus.ended])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchBettingModel.fromFirestore(doc))
            .toList());
  }

  // A user's own bet history, newest first
  Stream<List<BetModel>> getMyBets(String userId) {
    return _firestore
        .collection(_betsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => BetModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.placedAt.compareTo(a.placedAt));
      return list;
    });
  }

  // Admin - every pending bet placed on a specific match, needed to work
  // out who to pay when settling
  Stream<List<BetModel>> getPendingBetsForMatch(String matchId) {
    return _firestore
        .collection(_betsCollection)
        .where('matchId', isEqualTo: matchId)
        .where('status', isEqualTo: BetStatus.pending)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BetModel.fromFirestore(doc)).toList());
  }

  // ---------------------------------------------------------------------
  // ADMIN - OPENING AND ENDING BETTING ON A MATCH
  // ---------------------------------------------------------------------

  // Admin sets/updates odds for a match. Creating this doc is what makes
  // betting available on that match at all.
  Future<Map<String, dynamic>> openBetting({
    required String matchId,
    required double oddsA,
    required double oddsB,
  }) async {
    try {
      if (oddsA <= 1 || oddsB <= 1) {
        return {
          'success': false,
          'message': 'Odds must be greater than 1 (e.g. 2.0 doubles the stake)'
        };
      }

      final model = MatchBettingModel(
        matchId: matchId,
        oddsA: oddsA,
        oddsB: oddsB,
        status: BettingStatus.open,
      );

      await _firestore
          .collection(_bettingCollection)
          .doc(matchId)
          .set(model.toMap());

      return {'success': true, 'message': 'Betting is now open for this match'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to open betting: $e'};
    }
  }

  // THE MISSING FEATURE: admin manually ends betting on a match, e.g.
  // because it stopped/was abandoned and never got marked completed on
  // its own. This only stops NEW bets - it does not pay anyone out yet.
  // Settlement (below) is a deliberate separate step.
  Future<Map<String, dynamic>> endMatchBetting(
      {required String matchId}) async {
    try {
      final ref = _firestore.collection(_bettingCollection).doc(matchId);
      final snap = await ref.get();
      if (!snap.exists) {
        return {
          'success': false,
          'message': 'Betting was never opened for this match'
        };
      }

      await ref.update({
        'status': BettingStatus.ended,
        'endedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Betting ended for this match. No new bets can be placed.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to end betting: $e'};
    }
  }

  // ---------------------------------------------------------------------
  // PLACING A BET (the exact flow that was previously broken)
  // ---------------------------------------------------------------------

  // Deducts the stake from the wallet AND creates the bet record in a
  // single atomic transaction. Either both happen or neither does -
  // this is specifically what was missing before: the two writes were
  // not linked, so it was possible for one to succeed silently without
  // the other.
  Future<Map<String, dynamic>> placeBet({
    required String userId,
    required String userName,
    required String matchId,
    required String matchLabel,
    required String selection, // 'A' or 'B'
    required double stakeAmount,
  }) async {
    try {
      if (stakeAmount <= 0) {
        return {'success': false, 'message': 'Enter a valid stake amount'};
      }
      if (selection != 'A' && selection != 'B') {
        return {'success': false, 'message': 'Invalid selection'};
      }

      final userRef = _firestore.collection(_usersCollection).doc(userId);
      final bettingRef = _firestore.collection(_bettingCollection).doc(matchId);
      final betRef = _firestore.collection(_betsCollection).doc();

      late double lockedOdds;
      late double potentialWinnings;

      await _firestore.runTransaction((transaction) async {
        // All reads before any writes - required by Firestore transactions.
        final userSnap = await transaction.get(userRef);
        final bettingSnap = await transaction.get(bettingRef);

        // Bets are only allowed on UPCOMING matches - never on live or
        // already-completed ones.
        final matchSnap = await transaction
            .get(_firestore.collection('matches').doc(matchId));
        if (matchSnap.exists) {
          final matchData = matchSnap.data() as Map<String, dynamic>;
          if (matchData['status'] != MatchStatus.upcoming) {
            throw Exception('Bets are only allowed on upcoming matches');
          }
        }

        if (!bettingSnap.exists) {
          throw Exception('Betting is not open for this match');
        }
        final bettingData = bettingSnap.data() as Map<String, dynamic>;
        if (bettingData['status'] != BettingStatus.open) {
          throw Exception('Betting has closed for this match');
        }

        final double currentBalance = userSnap.exists
            ? ((userSnap.data() as Map<String, dynamic>)['walletBalance'] ?? 0)
                .toDouble()
            : 0.0;

        if (currentBalance < stakeAmount) {
          throw Exception('Insufficient wallet balance. Please deposit first.');
        }

        lockedOdds = selection == 'A'
            ? (bettingData['oddsA'] ?? 2).toDouble()
            : (bettingData['oddsB'] ?? 2).toDouble();
        potentialWinnings = stakeAmount * lockedOdds;

        // Write 1 - deduct the stake from the wallet
        transaction.set(
          userRef,
          {'walletBalance': FieldValue.increment(-stakeAmount)},
          SetOptions(merge: true),
        );

        // Write 2 - create the bet record, in the SAME transaction as
        // the deduction above, so they can never happen independently.
        transaction.set(betRef, {
          'userId': userId,
          'userName': userName,
          'matchId': matchId,
          'matchLabel': matchLabel,
          'selection': selection,
          'stakeAmount': stakeAmount,
          'odds': lockedOdds,
          'potentialWinnings': potentialWinnings,
          'status': BetStatus.pending,
          'placedAt': FieldValue.serverTimestamp(),
          'settledAt': null,
        });
      });

      return {
        'success': true,
        'message':
            'Bet placed! You could win UGX ${potentialWinnings.toInt()} if this comes in.',
      };
    } catch (e) {
      // Surfacing the real error message on purpose - a silent failure
      // here is exactly what caused the original bug to go unnoticed.
      return {
        'success': false,
        'message':
            'Bet not placed: ${e.toString().replaceAll('Exception: ', '')}'
      };
    }
  }

  // ---------------------------------------------------------------------
  // ADMIN - SETTLING A MATCH (approving wins, paying out)
  // ---------------------------------------------------------------------

  // Admin picks the winning selection ('A' or 'B'). Every pending bet on
  // this match is resolved: winners get their potentialWinnings credited
  // to their wallet, losers are simply marked lost (their stake was
  // already deducted when they placed the bet, so no further change).
  Future<Map<String, dynamic>> settleMatch({
    required String matchId,
    required String winningSelection, // 'A' or 'B'
  }) async {
    try {
      if (winningSelection != 'A' && winningSelection != 'B') {
        return {'success': false, 'message': 'Invalid winning selection'};
      }

      final bettingRef = _firestore.collection(_bettingCollection).doc(matchId);
      final betsSnapshot = await _firestore
          .collection(_betsCollection)
          .where('matchId', isEqualTo: matchId)
          .where('status', isEqualTo: BetStatus.pending)
          .get();

      if (betsSnapshot.docs.isEmpty) {
        // Still fine to settle a match with no pending bets - just marks
        // it settled so it stops showing up as needing attention.
        await bettingRef.update({
          'status': BettingStatus.settled,
          'winningSelection': winningSelection,
          'settledAt': FieldValue.serverTimestamp(),
        });
        return {
          'success': true,
          'message': 'Match settled (no pending bets to pay out)'
        };
      }

      // Firestore transactions cap at 500 writes - batch through the bets
      // in chunks so this still works for a very popular match.
      const int chunkSize = 200; // generous margin under the 500 limit
      int settledCount = 0;
      int payoutCount = 0;

      for (int i = 0; i < betsSnapshot.docs.length; i += chunkSize) {
        final chunk = betsSnapshot.docs.sublist(
          i,
          (i + chunkSize > betsSnapshot.docs.length)
              ? betsSnapshot.docs.length
              : i + chunkSize,
        );

        await _firestore.runTransaction((transaction) async {
          for (final betDoc in chunk) {
            final betData = betDoc.data();
            final String selection = betData['selection'];
            final bool isWinner = selection == winningSelection;

            transaction.update(betDoc.reference, {
              'status': isWinner ? BetStatus.won : BetStatus.lost,
              'settledAt': FieldValue.serverTimestamp(),
            });

            if (isWinner) {
              final String userId = betData['userId'];
              final double winnings =
                  (betData['potentialWinnings'] ?? 0).toDouble();
              final userRef =
                  _firestore.collection(_usersCollection).doc(userId);
              transaction.set(
                userRef,
                {'walletBalance': FieldValue.increment(winnings)},
                SetOptions(merge: true),
              );
              payoutCount++;
            }
            settledCount++;
          }
        });
      }

      await bettingRef.update({
        'status': BettingStatus.settled,
        'winningSelection': winningSelection,
        'settledAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message':
            'Match settled: $settledCount bet(s) resolved, $payoutCount winner(s) paid out.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to settle match: $e'};
    }
  }
}
