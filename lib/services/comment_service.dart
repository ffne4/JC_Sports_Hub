import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Comments are stored as a subcollection inside each post document
  // Structure: posts/{postId}/comments/{commentId}
  // This keeps comments grouped with their post automatically
  CollectionReference _commentsRef(String postId) {
    return _firestore.collection('posts').doc(postId).collection('comments');
  }

  // Stream of all comments for a post - updates in real time
  Stream<List<CommentModel>> getComments(String postId) {
    return _commentsRef(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromFirestore(doc))
            .toList());
  }

  // Add a new comment to a post
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userType,
    required String content,
  }) async {
    try {
      await _commentsRef(postId).add({
        'postId': postId,
        'userId': userId,
        'userName': userName,
        'userType': userType,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also increment the comment count on the post document
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      return {'success': true, 'message': 'Comment posted!'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to post comment: $e'};
    }
  }

  // Admin or comment owner can delete a comment
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _commentsRef(postId).doc(commentId).delete();

    // Decrement comment count on the post
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }
}
