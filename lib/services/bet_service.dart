import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bet_model.dart';

class BetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _bets =>
      _firestore.collection('bets');

  Stream<List<BetModel>> getUserBets() {
    if (_currentUserId == null) return const Stream.empty();
    return _bets
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BetModel.fromFirestore(doc))
            .toList());
  }

  Stream<BetModel?> getRecentBet(String matchId) {
    if (_currentUserId == null) return const Stream.empty();
    return _bets
        .where('userId', isEqualTo: _currentUserId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return BetModel.fromFirestore(snapshot.docs.first);
        });
  }

  Future<Map<String, dynamic>> settleBet({
    required String betId,
    required BetStatus status,
    required String adminId,
  }) async {
    try {
      final betRef = _bets.doc(betId);
      final betDoc = await betRef.get();
      if (!betDoc.exists) {
        return {'success': false, 'message': 'Bet not found'};
      }

      final betData = betDoc.data() as Map<String, dynamic>;
      if (betData['status'] != 'pending') {
        return {'success': false, 'message': 'Bet already settled'};
      }

      await betRef.update({
        'status': status.name,
        'settledAt': FieldValue.serverTimestamp(),
        'settledBy': adminId,
      });

      return {
        'success': true,
        'message': 'Bet marked as ${status.name}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to settle bet: $e'};
    }
  }

  Future<Map<String, dynamic>> syncBetFromTransaction(String transactionId) async {
    try {
      final txDoc = await _firestore.collection('transactions').doc(transactionId).get();
      if (!txDoc.exists) {
        return {'success': false, 'message': 'Transaction not found'};
      }

      final txData = txDoc.data() as Map<String, dynamic>;
      
      final existingBet = await _bets
          .where('userId', isEqualTo: txData['userId'])
          .where('matchId', isEqualTo: txData['matchId'])
          .limit(1)
          .get();

      if (existingBet.docs.isNotEmpty) {
        return {'success': false, 'message': 'Bet already synced'};
      }

      final betRef = _bets.doc();
      await betRef.set({
        'userId': txData['userId'],
        'userName': txData['userName'],
        'userMomoNumber': txData['userMomoNumber'],
        'matchId': txData['matchId'],
        'matchName': txData['description'] ?? '',
        'betTeam': txData['betTeam'] ?? '',
        'betTeamName': txData['betTeam'] ?? '',
        'amount': txData['amount'],
        'oddsAtPlacement': txData['oddsAtPlacement'] ?? 1.5,
        'potentialWinnings': txData['potentialWinnings'] ?? 0,
        'status': 'pending',
        'reference': txData['reference'],
        'description': txData['description'],
        'createdAt': txData['createdAt'],
        'settledAt': null,
        'settledBy': null,
      });

      return {'success': true, 'betId': betRef.id};
    } catch (e) {
      return {'success': false, 'message': 'Failed to sync bet: $e'};
    }
  }
}
