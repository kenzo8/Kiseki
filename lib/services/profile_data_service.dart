import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/seki_model.dart';
import '../models/want_model.dart';

/// Service to cache and manage profile data (devices and wants)
/// Uses ChangeNotifier for state management without requiring Provider package
class ProfileDataService extends ChangeNotifier {
  static ProfileDataService? _instance;
  static ProfileDataService get instance {
    _instance ??= ProfileDataService._();
    return _instance!;
  }

  ProfileDataService._();

  List<Seki>? _cachedSekis;
  List<Want>? _cachedWants;
  DocumentSnapshot? _cachedUserData;
  bool _isLoadingSekis = false;
  bool _isLoadingWants = false;
  bool _isLoadingUserData = false;
  String? _currentUserId;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _sekiSubscription;
  StreamSubscription<QuerySnapshot>? _wantSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  List<Seki>? get cachedSekis => _cachedSekis;
  List<Want>? get cachedWants => _cachedWants;
  DocumentSnapshot? get cachedUserData => _cachedUserData;
  bool get isLoadingSekis => _isLoadingSekis;
  bool get isLoadingWants => _isLoadingWants;
  bool get isLoadingUserData => _isLoadingUserData;
  bool get hasData => _cachedSekis != null && _cachedWants != null && _cachedUserData != null;

  /// Initialize streams for the current user
  void initialize(String userId) {
    if (_currentUserId == userId && hasData) {
      // Already initialized for this user
      return;
    }

    _currentUserId = userId;
    _disposeSubscriptions();

    // Initialize user data stream
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      _cachedUserData = snapshot;
      _isLoadingUserData = false;
      notifyListeners();
    });

    // Initialize seki stream
    _isLoadingSekis = true;
    _sekiSubscription = FirebaseFirestore.instance
        .collection('seki')
        .where('uid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _cachedSekis = snapshot.docs.map((doc) => Seki.fromFirestore(doc)).toList();
      _isLoadingSekis = false;
      notifyListeners();
    }, onError: (error) {
      _isLoadingSekis = false;
      notifyListeners();
    });

    // Initialize wants stream
    _isLoadingWants = true;
    _wantSubscription = FirebaseFirestore.instance
        .collection('wants')
        .where('uid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _cachedWants = snapshot.docs.map((doc) => Want.fromFirestore(doc)).toList();
      _isLoadingWants = false;
      notifyListeners();
    }, onError: (error) {
      _isLoadingWants = false;
      notifyListeners();
    });
  }

  /// Manually refresh data (for pull-to-refresh)
  Future<void> refresh() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Force refresh by re-initializing
    _disposeSubscriptions();
    initialize(userId);
  }

  /// Clear cache (useful when user logs out)
  void clearCache() {
    _cachedSekis = null;
    _cachedWants = null;
    _cachedUserData = null;
    _currentUserId = null;
    _disposeSubscriptions();
    notifyListeners();
  }

  void _disposeSubscriptions() {
    _sekiSubscription?.cancel();
    _wantSubscription?.cancel();
    _userSubscription?.cancel();
    _sekiSubscription = null;
    _wantSubscription = null;
    _userSubscription = null;
  }

  @override
  void dispose() {
    _disposeSubscriptions();
    super.dispose();
  }
}
