import 'package:cloud_firestore/cloud_firestore.dart';

class Seki {
  final String id;
  final String uid;
  final String username;
  final String deviceName;
  final String deviceType;
  final int startYear; // For backward compatibility and non-precise mode
  final int? endYear; // null for 'Present', for backward compatibility and non-precise mode
  final Timestamp? startTime; // For precise mode
  final Timestamp? endTime; // null for 'Present', for precise mode
  final bool isPreciseMode; // Whether using precise dates or year ranges
  final Timestamp createdAt;
  final String note;

  Seki({
    required this.id,
    required this.uid,
    required this.username,
    required this.deviceName,
    required this.deviceType,
    required this.startYear,
    this.endYear,
    this.startTime,
    this.endTime,
    this.isPreciseMode = false,
    required this.createdAt,
    required this.note,
  });

  // Create Seki from Firestore document
  factory Seki.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Use publisherId if available, otherwise fall back to uid for backward compatibility
    final publisherId = data['publisherId'] as String? ?? data['uid'] as String;
    
    // Check if this is a precise mode entry
    final isPreciseMode = data['isPreciseMode'] as bool? ?? false;
    
    // Handle both old (year-based) and new (timestamp-based) formats
    int startYear;
    int? endYear;
    Timestamp? startTime;
    Timestamp? endTime;
    
    if (isPreciseMode && data['startTime'] != null) {
      // New format: use timestamps
      startTime = data['startTime'] as Timestamp;
      endTime = data['endTime'] as Timestamp?;
      // Extract years from timestamps for backward compatibility
      startYear = startTime.toDate().year;
      endYear = endTime?.toDate().year;
    } else {
      // Old format: use years directly
      startYear = data['startYear'] as int? ?? DateTime.now().year;
      endYear = data['endYear'] as int?;
      // Convert years to timestamps for precise mode compatibility
      startTime = Timestamp.fromDate(DateTime(startYear, 1, 1));
      if (endYear != null) {
        endTime = Timestamp.fromDate(DateTime(endYear, 12, 31));
      }
    }
    
    return Seki(
      id: doc.id,
      uid: publisherId, // Store publisherId in uid field for backward compatibility
      username: data['username'] as String? ?? 'Unknown',
      deviceName: data['deviceName'] as String,
      deviceType: data['deviceType'] as String,
      startYear: startYear,
      endYear: endYear,
      startTime: startTime,
      endTime: endTime,
      isPreciseMode: isPreciseMode,
      createdAt: data['createdAt'] as Timestamp,
      note: data['note'] as String? ?? '',
    );
  }

  // Get publisherId (alias for uid for clarity)
  String get publisherId => uid;

  // Convert Seki to Map for Firestore
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'uid': uid,
      'publisherId': uid, // Explicitly store publisherId
      'username': username,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'isPreciseMode': isPreciseMode,
      'createdAt': createdAt,
      'note': note,
    };
    
    if (isPreciseMode) {
      // Save timestamps for precise mode
      if (startTime != null) {
        map['startTime'] = startTime;
      }
      map['endTime'] = endTime;
      // Also save years for backward compatibility
      map['startYear'] = startYear;
      map['endYear'] = endYear;
    } else {
      // Save years for non-precise mode
      map['startYear'] = startYear;
      map['endYear'] = endYear;
    }
    
    return map;
  }

  // Get year range display string (handles both formats)
  String get yearRange {
    if (isPreciseMode && startTime != null) {
      final startDate = startTime!.toDate();
      if (endTime == null) {
        return '${startDate.year}/${startDate.month}/${startDate.day} – Present';
      } else {
        final endDate = endTime!.toDate();
        return '${startDate.year}/${startDate.month}/${startDate.day} – ${endDate.year}/${endDate.month}/${endDate.day}';
      }
    } else {
      if (endYear == null) {
        return '$startYear – Present';
      }
      return '$startYear – $endYear';
    }
  }
  
  // Get formatted date range for precise mode
  String get dateRange {
    if (isPreciseMode && startTime != null) {
      final startDate = startTime!.toDate();
      if (endTime == null) {
        return '${startDate.year}/${startDate.month}/${startDate.day} – Present';
      } else {
        final endDate = endTime!.toDate();
        return '${startDate.year}/${startDate.month}/${startDate.day} – ${endDate.year}/${endDate.month}/${endDate.day}';
      }
    } else {
      return yearRange;
    }
  }
}
