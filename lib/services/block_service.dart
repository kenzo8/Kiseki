import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage blocked users for Google Play UGC compliance.
/// Blocked user IDs are stored in the current user's Firestore document.
class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _fieldBlockedUserIds = 'blockedUserIds';

  /// Stream of the current user's blocked user IDs. Returns empty list if not logged in.
  Stream<List<String>> get blockedUserIdsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <String>[];
          final data = doc.data();
          final list = data?[_fieldBlockedUserIds];
          if (list is List) {
            return list.map((e) => e.toString()).toList();
          }
          return <String>[];
        });
  }

  /// One-time fetch of blocked user IDs.
  Future<List<String>> getBlockedUserIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data();
    final list = data?[_fieldBlockedUserIds];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Returns true if [userId] is blocked by the current user.
  Future<bool> isBlocked(String userId) async {
    final blocked = await getBlockedUserIds();
    return blocked.contains(userId);
  }

  /// Block a user. Does nothing if blocking self or already blocked.
  Future<void> blockUser(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not logged in');
    if (userId == uid) return; // Do not block self
    final ref = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? (snap.data()?[_fieldBlockedUserIds] as List<dynamic>?) ?? []
          : <dynamic>[];
      final list = current.map((e) => e.toString()).toList();
      if (list.contains(userId)) return;
      list.add(userId);
      tx.set(ref, {_fieldBlockedUserIds: list}, SetOptions(merge: true));
    });
  }

  /// Unblock a user.
  Future<void> unblockUser(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not logged in');
    final ref = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? (snap.data()?[_fieldBlockedUserIds] as List<dynamic>?) ?? []
          : <dynamic>[];
      final list = current.map((e) => e.toString()).where((id) => id != userId).toList();
      tx.set(ref, {_fieldBlockedUserIds: list}, SetOptions(merge: true));
    });
  }
}
