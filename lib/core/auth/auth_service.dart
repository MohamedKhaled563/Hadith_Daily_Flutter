import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around FirebaseAuth + GoogleSignIn.
///
/// `google_sign_in` 7.x needs its client IDs supplied explicitly for the
/// resulting idToken's audience to match what Firebase expects, so both are
/// passed here rather than left to platform auto-detection:
/// - `serverClientId` is the project's *web* OAuth client (the one Firebase
///   itself verifies idTokens against), needed on both platforms.
/// - `clientId` is the iOS app's own OAuth client, required only on iOS.
/// Thrown by [AuthService.signUpWithEmail] when another account claims the
/// same normalized display name in the moment between the sign-up screen's
/// own pre-check and this call — see the `usernames/` collection in
/// firestore.rules for how that race is closed.
class DisplayNameTakenException implements Exception {}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;

  static const _webClientId =
      '305295927502-f9mjfcg8nln4gptfnjk968o8ivikst1n.apps.googleusercontent.com';
  static const _iosClientId =
      '305295927502-4bqfmmrh77fbmjk4mqgd1b5fai0q2hnl.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleReady = false;

  // userChanges (not authStateChanges) so a displayName update right after
  // sign-up — see signUpWithEmail — is picked up without a separate sign-in.
  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  /// Normalizes a display name the same way on every check/claim so
  /// "Ahmed", " ahmed ", and "AHMED" all collide on one `usernames/` doc.
  String normalizeDisplayName(String name) =>
      name.trim().toLowerCase().replaceAll('/', '-');

  Future<bool> isDisplayNameTaken(String name) async {
    final key = normalizeDisplayName(name);
    if (key.isEmpty) return false;
    final doc = await _firestore.collection('usernames').doc(key).get();
    return doc.exists;
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await _googleSignIn.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? _iosClientId
          : null,
      serverClientId: _webClientId,
    );
    _googleReady = true;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(credential.user!);
    return credential;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Claim the normalized name right after the account exists (the write
    // needs request.auth to be this new user — see firestore.rules). If
    // someone else grabbed the same name in the moment between the sign-up
    // screen's own pre-check and here, the rules deny this as an update
    // against an already-existing doc; roll back the account rather than
    // leave an orphaned one behind.
    if (displayName.isNotEmpty) {
      final nameKey = normalizeDisplayName(displayName);
      try {
        await _firestore
            .collection('usernames')
            .doc(nameKey)
            .set({'uid': credential.user!.uid});
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          await credential.user?.delete();
          throw DisplayNameTakenException();
        }
        rethrow;
      }

      await credential.user?.updateDisplayName(displayName);
      // updateDisplayName() writes the new name to the Auth server, but the
      // in-memory User object we're already holding doesn't pick it up on
      // its own — without this reload, _ensureUserDoc below reads the
      // stale (empty) displayName and mirrors that into Firestore instead.
      await credential.user?.reload();
    }

    await _ensureUserDoc(_auth.currentUser ?? credential.user!);
    return credential;
  }

  /// Returns null if the reader dismisses the Google account picker rather
  /// than completing sign-in — that's a normal cancellation, not an error.
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleReady();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(userCredential.user!);
    return userCredential;
  }

  /// Mirrors the signed-in user into `users/{uid}` — see firestore.rules
  /// (phase 4): created once with displayName/email/createdAt, refreshed on
  /// every later sign-in in case displayName changed. `role` is never
  /// touched here; only an existing admin (from the dashboard's Users tab)
  /// or `tool/set_role.py` for bootstrapping ever sets it — see phase 11.
  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (snapshot.data()?['displayName'] != user.displayName) {
      await ref.update({'displayName': user.displayName ?? ''});
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleReady) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Not signed in via Google, or already signed out — fine either way.
      }
    }
  }
}
