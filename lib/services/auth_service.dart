import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Generate default username from email (public method for reuse)
  String generateDefaultUsername(String email) {
    final emailPrefix = email.split('@').first;
    // Extract first 4 characters (or numeric part if available)
    final numericMatch = RegExp(r'\d+').firstMatch(emailPrefix);
    if (numericMatch != null) {
      final numericPart = numericMatch.group(0)!;
      return 'user${numericPart.length >= 4 ? numericPart.substring(0, 4) : numericPart}';
    }
    // If no numeric part, use first 4 characters of email prefix
    return 'user${emailPrefix.length >= 4 ? emailPrefix.substring(0, 4) : emailPrefix}';
  }

  /// Generate a short handle base from email (lowercase, alphanumeric + underscore, max 12 chars).
  String generateHandleFromEmail(String email) {
    final prefix = email.split('@').first.toLowerCase();
    final sanitized = prefix.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (sanitized.isEmpty) return 'u';
    return sanitized.length > 12 ? sanitized.substring(0, 12) : sanitized;
  }

  /// Ensure handle is unique; if base is taken, append _last5(uid). Returns the handle to use.
  Future<String> ensureUniqueHandle(String baseHandle, String uid) async {
    final handlesRef = _firestore.collection('handles');
    var candidate = baseHandle;
    final doc = await handlesRef.doc(candidate).get();
    if (!doc.exists) return candidate;
    candidate = '${baseHandle}_${uid.length >= 5 ? uid.substring(uid.length - 5) : uid}';
    return candidate;
  }

  // Sign up with email, password, and optional username
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      // Step 1: Auth First - Create user in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (cred.user == null) {
        throw 'Failed to create user account';
      }

      final uid = cred.user!.uid;

      // Step 2: Generate username if not provided
      final finalUsername = username?.trim().isEmpty ?? true
          ? generateDefaultUsername(email)
          : username!.trim();

      // Step 2b: Generate unique short handle from email
      final baseHandle = generateHandleFromEmail(email.trim());
      final handle = await ensureUniqueHandle(baseHandle, uid);

      // Step 3: Firestore Second (MUST AWAIT) - Create user profile and handle
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'username': finalUsername,
        'handle': handle,
        'email': email.trim(),
        'createdAt': DateTime.now(),
      });
      await _firestore.collection('handles').doc(handle).set({'uid': uid});

      // Step 4: Check Success
      print('User profile created successfully');

      // Step 5: Return user credential (navigation will be handled by StreamBuilder in main.dart)
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on FirebaseException catch (e) {
      // If Firestore write fails, try to clean up the auth user
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
      throw 'Failed to create user profile: ${e.message ?? e.code}. Please check Firestore rules.';
    } catch (e) {
      // If any other error occurs, try to clean up the auth user
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
      if (e is String) {
        rethrow;
      }
      throw 'An unexpected error occurred: $e';
    }
  }

  // Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Log in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Log in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return userCredential;

      // Create or update Firestore user doc for Google sign-in
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      if (!doc.exists) {
        final username = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : generateDefaultUsername(user.email ?? '');
        final email = user.email ?? '';
        final baseHandle = generateHandleFromEmail(email);
        final handle = await ensureUniqueHandle(baseHandle, user.uid);
        await userRef.set({
          'uid': user.uid,
          'username': username,
          'handle': handle,
          'email': email,
          'createdAt': DateTime.now(),
        });
        await _firestore.collection('handles').doc(handle).set({'uid': user.uid});
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on PlatformException catch (e) {
      // ApiException 10 = DEVELOPER_ERROR: SHA-1 not in Firebase or OAuth client missing
      if (e.code == 'sign_in_failed' &&
          (e.message?.contains('ApiException') == true &&
              e.message?.contains('10') == true)) {
        throw 'Google sign-in is not available. Add SHA-1 fingerprint for your Android app in Firebase Console, '
            'then re-download google-services.json. See GOOGLE_SIGNIN_SETUP.md in the project root.';
      }
      throw 'Google sign-in failed: ${e.message ?? e.code}';
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  /// Delete account: remove user data from Firestore and delete Firebase Auth user.
  /// May throw [FirebaseAuthException] with code [requires-recent-login] if user
  /// has not signed in recently — in that case re-authenticate and try again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No user logged in';
    }
    final uid = user.uid;

    // 1. Delete user data from Firestore (batch max 500 ops)
    const batchMax = 500;
    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    final sekiSnap = await _firestore.collection('seki').where('uid', isEqualTo: uid).get();
    for (final doc in sekiSnap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= batchMax) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    final wantsSnap = await _firestore.collection('wants').where('uid', isEqualTo: uid).get();
    for (final doc in wantsSnap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= batchMax) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    String handle = '';
    if (userDoc.exists) {
      final data = userDoc.data();
      handle = data is Map<String, dynamic> ? (data['handle'] as String? ?? '') : '';
    }
    if (handle.isNotEmpty) {
      batch.delete(_firestore.collection('handles').doc(handle));
    }
    batch.delete(_firestore.collection('users').doc(uid));
    await batch.commit();

    // 2. Sign out Google if used (so token is revoked)
    await _googleSignIn.signOut();

    // 3. Delete Firebase Auth user (must be signed in; removes account and signs out)
    await user.delete();
  }

  /// User-friendly message for Firebase Auth exceptions (for UI).
  String authExceptionMessage(FirebaseAuthException e) => _handleAuthException(e);

  // Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
