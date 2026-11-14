import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

/// What happened when the server was asked to email a confirmation code.
enum EmailCodeSendStatus {
  /// A new code is on its way.
  sent,

  /// A limit applies (a code went out moments ago, or too many today);
  /// nothing was sent. [EmailCodeSend.waitSeconds] says for how long.
  wait,

  /// The address is already confirmed; there is nothing to send.
  verified,
}

class EmailCodeSend {
  const EmailCodeSend(this.status, {this.waitSeconds = 0});
  final EmailCodeSendStatus status;

  /// Seconds until another code may be asked for.
  final int waitSeconds;
}

/// What the server said about a code the reader typed.
enum EmailCodeCheckStatus {
  verified,
  wrong,
  expired,
  tooManyAttempts,

  /// No live code for this account — one has to be asked for.
  noCode,
}

class EmailCodeCheck {
  const EmailCodeCheck(this.status, {this.attemptsLeft = 0});
  final EmailCodeCheckStatus status;
  final int attemptsLeft;
}

/// What the server said about a password-reset code and new password.
enum PasswordResetStatus {
  reset,
  wrong,
  expired,
  tooManyAttempts,

  /// No live code for this address — including when it has no account,
  /// which the server never reveals.
  noCode,
}

class PasswordResetResult {
  const PasswordResetResult(this.status, {this.attemptsLeft = 0});
  final PasswordResetStatus status;
  final int attemptsLeft;
}

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
  // Same region the functions deploy to (functions/src/index.ts).
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
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
      clientId:
          defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
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
    await _mirrorUserDocBestEffort(credential.user!);
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

    // Everything from here on runs against an already-created account: if
    // any of it fails, roll the account back rather than leave it stranded
    // half set-up. The username claim is deliberately done *last*, after
    // updateDisplayName/reload and _ensureUserDoc already succeeded: a
    // usernames/{key} doc can never be edited or deleted once claimed (see
    // firestore.rules), so if that step failed partway through this
    // sequence, the name would be permanently unusable by anyone even
    // though the account claiming it was rolled back. Doing it last means
    // the only thing that can still fail after it succeeds is nothing — and
    // if it fails, the worst orphan left behind is a stray users/{uid} doc
    // keyed by a uid nobody will ever collide with, not a human-readable
    // name blocked forever. The one exception is a name collision, which
    // already has its own specific rollback+error below.
    try {
      if (displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
        // updateDisplayName() writes the new name to the Auth server, but
        // the in-memory User object we're already holding doesn't pick it
        // up on its own — without this reload, _ensureUserDoc below reads
        // the stale (empty) displayName and mirrors that into Firestore
        // instead.
        await credential.user?.reload();
      }

      await _ensureUserDoc(_auth.currentUser ?? credential.user!);

      // Claim the normalized name last (the write needs request.auth to be
      // this new user — see firestore.rules). If someone else grabbed the
      // same name in the moment between the sign-up screen's own pre-check
      // and here, the rules deny this as an update against an
      // already-existing doc.
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
      }
    } on DisplayNameTakenException {
      rethrow;
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }

    return credential;
  }

  /// Returns null if the reader dismisses the Google account picker rather
  /// than completing sign-in — that's a normal cancellation, not an error.
  Future<UserCredential?> signInWithGoogle() async {
    final credential = await googleCredential();
    if (credential == null) return null;

    final userCredential = await _auth.signInWithCredential(credential);
    await _mirrorUserDocBestEffort(userCredential.user!);
    return userCredential;
  }

  /// Shows the Google account picker and returns a Firebase credential for
  /// the chosen account without signing in with it. Null if dismissed.
  ///
  /// Account deletion re-authenticates with this rather than
  /// [signInWithGoogle]: signing in would quietly switch to whichever account
  /// the reader tapped in the picker, and the deletion would then remove
  /// *that* account instead of the one they meant.
  Future<OAuthCredential?> googleCredential() async {
    await _ensureGoogleReady();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    return GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
  }

  /// Whether this device can offer Sign in with Apple.
  ///
  /// App Store Guideline 4.8 makes Apple sign-in the equivalent-login
  /// option alongside Google, so the button must be offered on iOS. It is
  /// pointless on Android, where the web flow would open a browser to
  /// authenticate against an Apple ID the reader is not signed into on this
  /// device — Google and email already cover that case, so callers hide the
  /// button rather than show one that leads nowhere.
  Future<bool> get isAppleSignInAvailable async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return SignInWithApple.isAvailable();
  }

  /// Returns null if the reader dismisses the Apple sheet — a normal
  /// cancellation, matching [signInWithGoogle]'s contract.
  ///
  /// The nonce is not ceremony. Firebase verifies that the SHA-256 hash it
  /// finds inside Apple's signed identity token matches the raw nonce we
  /// hand it here, which is what stops a token captured from one app being
  /// replayed against another. Apple only ever sees the hash; Firebase only
  /// ever sees the raw value.
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Apple hands over the reader's name exactly once — on the very first
    // authorization for this App ID — and never again, not even after a
    // reinstall. Firebase does not fold it into the account on its own, so
    // if it is not captured here the reader is left permanently nameless
    // and shows up in the community feed as an empty byline. Every later
    // sign-in arrives with givenName null and displayName already set, so
    // this runs once and then never fires again.
    if ((user.displayName ?? '').trim().isEmpty) {
      final name = [appleCredential.givenName, appleCredential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
        await user.reload();
      }
    }

    await _mirrorUserDocBestEffort(_auth.currentUser ?? user);
    return userCredential;
  }

  /// A cryptographically random nonce, in the URL-safe alphabet Apple
  /// accepts. [Random.secure] rather than [Random]: a predictable nonce
  /// defeats the replay protection it exists to provide.
  static String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// [_ensureUserDoc], but never fatal — for the two *sign-in* paths, where
  /// FirebaseAuth has already accepted the reader by the time this runs.
  ///
  /// Letting the mirror throw used to abort a sign-in that had in fact
  /// succeeded: the reader saw a generic failure and stayed on the login
  /// screen while FirebaseAuth quietly kept the session, so the very next
  /// app start dropped them into Home as if nothing had happened. Any
  /// Firestore hiccup — an unreachable backend, a transient rules error —
  /// was enough to trigger it. The mirror is pure bookkeeping (displayName
  /// and email for the dashboard's user list), so a failure is logged and
  /// retried on the reader's next sign-in instead.
  ///
  /// Sign-*up* deliberately keeps the strict [_ensureUserDoc]: a brand-new
  /// account with no users/ doc and no claimed display name is worth rolling
  /// back rather than half-creating.
  Future<void> _mirrorUserDocBestEffort(User user) async {
    try {
      await _ensureUserDoc(user);
    } catch (error, stackTrace) {
      debugPrint('users/${user.uid} mirror failed after sign-in: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  // ------------------------------------------------- email confirmation ----
  //
  // An email/password account proves it owns its address by typing a
  // six-digit code we email it. The code is made, stored, sent and checked by
  // the Cloud Functions in functions/src/index.ts — never on the phone, where
  // it could be read out of the app or the check skipped. Google and Apple
  // accounts arrive already verified by their provider and never see this.

  /// True for a signed-in email/password account that hasn't confirmed its
  /// address yet.
  bool get needsEmailCode {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Whether "change email" is offered: the server only discards an
  /// unconfirmed account in its first day (see discardUnverifiedAccount).
  /// An hour short of that, so the button never offers something the server
  /// is about to refuse.
  bool get canDiscardUnverifiedAccount {
    final created = _auth.currentUser?.metadata.creationTime;
    if (created == null || !needsEmailCode) return false;
    return DateTime.now().difference(created) < const Duration(hours: 23);
  }

  Future<Map<String, dynamic>> _callFunction(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await _functions.httpsCallable(name).call<Object?>(data);
    final reply = result.data;
    return reply is Map ? Map<String, dynamic>.from(reply) : const {};
  }

  /// Asks the server to email a new code to this account's own address.
  Future<EmailCodeSend> sendEmailCode() async {
    final data = await _callFunction('sendEmailCode');
    switch (data['status']) {
      case 'sent':
        return EmailCodeSend(
          EmailCodeSendStatus.sent,
          waitSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
        );
      case 'wait':
        return EmailCodeSend(
          EmailCodeSendStatus.wait,
          waitSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 60,
        );
      default:
        await _refreshVerified();
        return const EmailCodeSend(EmailCodeSendStatus.verified);
    }
  }

  /// Checks a typed code. On success the account is verified server-side and
  /// the local ID token is refreshed, so the security rules (which read
  /// `email_verified` from it) see the change at once.
  Future<EmailCodeCheck> verifyEmailCode(String code) async {
    final data = await _callFunction('verifyEmailCode', {'code': code});
    switch (data['status']) {
      case 'verified':
        await _refreshVerified();
        return const EmailCodeCheck(EmailCodeCheckStatus.verified);
      case 'wrong':
        return EmailCodeCheck(
          EmailCodeCheckStatus.wrong,
          attemptsLeft: (data['attemptsLeft'] as num?)?.toInt() ?? 0,
        );
      case 'expired':
        return const EmailCodeCheck(EmailCodeCheckStatus.expired);
      case 'too-many-attempts':
        return const EmailCodeCheck(EmailCodeCheckStatus.tooManyAttempts);
      default:
        return const EmailCodeCheck(EmailCodeCheckStatus.noCode);
    }
  }

  /// Deletes a brand-new account whose address turned out to be mistyped,
  /// releasing its display name, and signs out. Server-side, so it never
  /// stops to demand a fresh sign-in.
  Future<void> discardUnverifiedAccount() async {
    await _callFunction('discardUnverifiedAccount');
    await signOut();
  }

  Future<void> _refreshVerified() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
  }

  // --------------------------------------------------- password reset ----
  //
  // The phone app resets a forgotten password with the same six-digit code,
  // from the app's own address, typed here with the new password
  // (functions/src/index.ts: sendPasswordResetCode, resetPasswordWithCode).
  // The server answers the same whether or not the address has an account.

  /// Asks for a reset code to [email]. [EmailCodeSendStatus.verified] is
  /// never returned here.
  Future<EmailCodeSend> sendPasswordResetCode(String email) async {
    final data = await _callFunction('sendPasswordResetCode', {
      'email': email.trim(),
    });
    if (data['status'] == 'wait') {
      return EmailCodeSend(
        EmailCodeSendStatus.wait,
        waitSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 60,
      );
    }
    return EmailCodeSend(
      EmailCodeSendStatus.sent,
      waitSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  /// Sets [newPassword] if [code] is right, then signs in with it. The
  /// server also marks the address verified (the code proved the inbox) and
  /// signs the account out everywhere else.
  Future<PasswordResetResult> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _callFunction('resetPasswordWithCode', {
      'email': email.trim(),
      'code': code,
      'newPassword': newPassword,
    });
    switch (data['status']) {
      case 'reset':
        await signInWithEmail(email: email.trim(), password: newPassword);
        return const PasswordResetResult(PasswordResetStatus.reset);
      case 'wrong':
        return PasswordResetResult(
          PasswordResetStatus.wrong,
          attemptsLeft: (data['attemptsLeft'] as num?)?.toInt() ?? 0,
        );
      case 'expired':
        return const PasswordResetResult(PasswordResetStatus.expired);
      case 'too-many-attempts':
        return const PasswordResetResult(PasswordResetStatus.tooManyAttempts);
      default:
        return const PasswordResetResult(PasswordResetStatus.noCode);
    }
  }

  /// Firebase's own reset link. Only the staff dashboard still uses it; the
  /// phone app uses [sendPasswordResetCode].
  Future<void> sendPasswordResetEmail(String email) async {
    // Firebase's own reset email follows this, not the phone's language;
    // without it readers got the English template.
    await _auth.setLanguageCode('ar');
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
