import 'package:cloud_firestore/cloud_firestore.dart';

// This class represents a single post in the feed
// Think of it as the blueprint for what every post looks like
class PostModel {
  final String id; // Unique post ID
  final String userId; // Who posted it
  final String userName; // Display name of poster
  final String userType; // bachelor, diploma, guest
  final String content; // The actual post text
  final String imageUrl; // Optional image (empty string if none)
  final String status; // 'pending', 'approved', 'rejected'
  final bool isAnnouncement; // True if admin posted this as announcement
  final int likeCount; // Number of likes
  final int _commentCount;
  final List<String> likedBy; // List of userIds who liked
  final DateTime createdAt; // When it was posted
  final String sport; // Football, Basketball etc (optional filter)

  int get commentCount => _commentCount;

  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.content,
    required this.imageUrl,
    required this.status,
    required this.isAnnouncement,
    required int commentCount,
    required this.likeCount,
    required this.likedBy,
    required this.createdAt,
    required this.sport,
  }) : _commentCount = commentCount;

  // Factory constructor - creates a PostModel from a Firestore document
  // 'factory' means this constructor can return an existing instance or create new
  // We use it here to convert raw Firestore data (a Map) into a clean PostModel object
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    // doc.data() returns the document fields as a Map<String, dynamic>
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userType: data['userType'] ?? 'guest',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      isAnnouncement: data['isAnnouncement'] ?? false,
      commentCount: data['commentCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      // List.from() safely converts a dynamic list to List<String>
      likedBy: List<String>.from(data['likedBy'] ?? []),
      // Timestamp is Firestore's date type - .toDate() converts to Dart DateTime
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sport: data['sport'] ?? 'General',
    );
  }

  // Converts a PostModel back to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userType': userType,
      'content': content,
      'imageUrl': imageUrl,
      'status': status,
      'isAnnouncement': isAnnouncement,
      'commentCount': commentCount,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'sport': sport,
    };
  }
}
