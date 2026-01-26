import 'package:cloud_firestore/cloud_firestore.dart';

class Want {
  final String id;
  final String uid;
  final String username;
  final String deviceName;
  final String deviceType;
  final Timestamp createdAt;

  Want({
    required this.id,
    required this.uid,
    required this.username,
    required this.deviceName,
    required this.deviceType,
    required this.createdAt,
  });

  // Create Want from Firestore document
  factory Want.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Want(
      id: doc.id,
      uid: data['uid'] as String,
      username: data['username'] as String? ?? 'Unknown',
      deviceName: data['deviceName'] as String,
      deviceType: data['deviceType'] as String,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  // Convert Want to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'username': username,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'createdAt': createdAt,
    };
  }
}
