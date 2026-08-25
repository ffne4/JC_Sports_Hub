import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 'posts' is our Firestore collection name - like a database table
  static const String _collection = 'posts';

  // Returns a Stream of approved posts + announcements for the home feed
  // Stream means Firestore sends us live updates whenever data changes
  // So if admin approves a post, it appears in the feed WITHOUT refreshing
  Stream<List<PostModel>> getFeedPosts() {
    return _firestore
        .collection(_collection)
        // where() filters documents - we only want approved posts
        .where('status', isEqualTo: 'approved')
        // orderBy sorts results - newest posts first
        .orderBy('createdAt', descending: true)
        // snapshots() returns a Stream that updates in real time
        .snapshots()
        // .map() transforms each snapshot into a List<PostModel>
        .map((snapshot) {
      return snapshot.docs
          // .map() converts each document into a PostModel
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
  }

  // Returns only announcements (admin posts) for the banner
  Stream<List<PostModel>> getAnnouncements() {
    return _firestore
        .collection(_collection)
        .where('isAnnouncement', isEqualTo: true)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        // limit() restricts to 5 most recent announcements
        .limit(5)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  // Creates a new post - starts as 'pending' until admin approves
  Future<Map<String, dynamic>> createPost({
    required String userId,
    required String userName,
    required String userType,
    required String content,
    String imageUrl = '',
    String sport = 'General',
  }) async {
    try {
      // Add a new document to 'posts' collection
      // Firestore auto-generates the document ID
      await _firestore.collection(_collection).add({
        'userId': userId,
        'userName': userName,
        'userType': userType,
        'content': content,
        'imageUrl': imageUrl,
        'status': 'pending', // Always starts as pending
        'isAnnouncement': false,
        'likeCount': 0,
        'likedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'sport': sport,
      });

      return {
        'success': true,
        'message': 'Post submitted! Waiting for admin approval.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create post. Please try again.',
      };
    }
  }

  // Toggles like on a post - if already liked, unlikes it
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final postRef = _firestore.collection(_collection).doc(postId);

    if (isLiked) {
      // FieldValue.arrayRemove() removes userId from the likedBy list
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
        // increment(-1) decreases likeCount by 1
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      // FieldValue.arrayUnion() adds userId to likedBy (no duplicates)
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([userId]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // Admin only - gets all pending posts waiting for approval
  Stream<List<PostModel>> getPendingPosts() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  // Admin only - approves a post making it visible to everyone. The author
  // gets an in-app notification so they know it went live.
  Future<void> approvePost(String postId) async {
    final postDoc = await _firestore.collection(_collection).doc(postId).get();
    await _firestore.collection(_collection).doc(postId).update({
      'status': 'approved',
    });
    if (postDoc.exists) {
      final userId =
          (postDoc.data() as Map<String, dynamic>)['userId'] ?? '';
      if (userId is String && userId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'Post approved 🎉',
          'message': 'Your post is now live in the community feed.',
          'type': 'post',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
        });
      }
    }
  }

  // Admin only - rejects and deletes a post
  Future<void> deletePost(String postId) async {
    await _firestore.collection(_collection).doc(postId).delete();
  }
}
