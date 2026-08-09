import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? referenceId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    final ts = map['createdAt'];
    DateTime parsed;
    if (ts is Timestamp) {
      parsed = ts.toDate();
    } else if (ts is String) {
      parsed = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsed = DateTime.now();
    }

    return NotificationModel(
      id: docId,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'general',
      isRead: map['isRead'] ?? false,
      createdAt: parsed,
      referenceId: map['referenceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
      'referenceId': referenceId,
    };
  }
}
