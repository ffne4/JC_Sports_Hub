import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Future<void> addNotification({
    required String title,
    required String message,
    String type = 'general',
    String? referenceId,
  }) async {
    if (_userId == null) return;

    await _col.add({
      'userId': _userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'referenceId': referenceId,
    });
  }

  Stream<List<NotificationModel>> getNotifications() {
    if (_userId == null) return const Stream.empty();

    return _col
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<int> getUnreadCount() async {
    if (_userId == null) return 0;

    final snapshot = await _col
        .where('userId', isEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    final snapshot = await _col
        .where('userId', isEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }
}
