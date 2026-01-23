import 'package:cloud_firestore/cloud_firestore.dart';

class Seki {
  final String id;
  final String uid;
  final String deviceName;
  final String deviceType;
  final int startYear;
  final int? endYear; // null for 'Present'
  final Timestamp createdAt;
  final String note;

  Seki({
    required this.id,
    required this.uid,
    required this.deviceName,
    required this.deviceType,
    required this.startYear,
    this.endYear,
    required this.createdAt,
    required this.note,
  });

  // Create Seki from Firestore document
  factory Seki.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Seki(
      id: doc.id,
      uid: data['uid'] as String,
      deviceName: data['deviceName'] as String,
      deviceType: data['deviceType'] as String,
      startYear: data['startYear'] as int,
      endYear: data['endYear'] as int?,
      createdAt: data['createdAt'] as Timestamp,
      note: data['note'] as String? ?? '',
    );
  }

  // Convert Seki to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'startYear': startYear,
      'endYear': endYear,
      'createdAt': createdAt,
      'note': note,
    };
  }

  // Get year range display string
  String get yearRange {
    if (endYear == null) {
      return '$startYear - Present';
    }
    return '$startYear - $endYear';
  }
}
