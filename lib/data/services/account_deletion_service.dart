import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/auth_service.dart';
import 'message_like_service.dart';

/// Which sign-in method an account uses, so the delete flow knows what kind
/// of re-authentication to ask for.
enum ReauthMethod { password, google, unsupported }

/// Deletes an account and everything it owns, from the client.
///
/// Google Play's Data Deletion policy and App Store guideline 5.1.1(v) both
/// require an in-app way to delete an account and its data. This app is
/// client-only and stays on Firebase's free Spark plan, so there are no Cloud
/// Functions to cascade the delete server-side — the client has to do it, in
/// an order that keeps it able to do the next step.
///
/// The order matters and is not arbitrary:
///
///  1. **Re-authenticate first.** `User.delete()` throws
///     `requires-recent-login` on a session older than a few minutes. Getting
///     that *after* wiping their Firestore data would leave an account that
///     still signs in but owns nothing. Re-auth is therefore a precondition
///     the UI satisfies before any of this runs.
///  2. **Un-like everything, before deleting their posts.** A like lives at
///     `<collection>/<messageId>/likes/{uid}` with a denormalised `likeCount`
///     on the parent. Removing the like through the same transaction the app
///     normally uses keeps the count honest; doing it after their own posts
///     were deleted would strand their like docs under missing parents.
///  3. **Their posts, then their feedback, then the profile doc, then the
///     username claim.** Each later step's rule depends on `request.auth`
///     still being this user, so the Auth account goes last.
///  4. **The Auth account.**
///
/// What this deliberately does not reach: the `likes/` subcollections *other
/// readers* left on posts being deleted. Firestore does not cascade, and the
/// rules only let a like's own owner remove it. Those docs are keyed by the
/// liker's uid and carry nothing about the account being deleted, so they are
/// a tidiness problem for a moderator rather than a privacy one — and saying
/// so is why the privacy policy mentions them.
class AccountDeletionService {
  AccountDeletionService._internal();
  static final AccountDeletionService instance =
      AccountDeletionService._internal();
  factory AccountDeletionService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessageLikeService _likes = MessageLikeService();

  /// How many like-probes to run at once. The scan below is one read per
  /// message (see [_removeAllLikes] for why it can't be a query), so this is
  /// the difference between a deletion that takes a moment and one that
  /// takes a minute — without opening the floodgates on a phone connection.
  static const _probeBatch = 16;

  /// How the signed-in account should re-authenticate.
  ReauthMethod get reauthMethod {
    final user = _auth.currentUser;
    if (user == null) return ReauthMethod.unsupported;

    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('password')) return ReauthMethod.password;
    if (providers.contains('google.com')) return ReauthMethod.google;
    return ReauthMethod.unsupported;
  }

  /// Proves the session is fresh enough for [deleteAccount].
  ///
  /// Throws [FirebaseAuthException] on a wrong password or a cancelled Google
  /// prompt, which the sheet turns into an inline message rather than a
  /// half-finished delete.
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    switch (reauthMethod) {
      case ReauthMethod.password:
        final email = user.email;
        if (email == null || password == null || password.isEmpty) {
          throw FirebaseAuthException(code: 'invalid-credential');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );

      case ReauthMethod.google:
        // A fresh Google sign-in returns a credential we can re-auth with.
        // AuthService owns the client-id wiring, so reuse it rather than
        // standing up a second GoogleSignIn here.
        final credential = await AuthService.instance.signInWithGoogle();
        if (credential == null) {
          throw FirebaseAuthException(code: 'cancelled-by-user');
        }

      case ReauthMethod.unsupported:
        throw FirebaseAuthException(code: 'unsupported-provider');
    }
  }

  /// Deletes everything this account owns, then the account.
  ///
  /// [onProgress] is called with a human-readable Arabic step so the overlay
  /// can say what is happening — a silent thirty-second wipe reads as a hang.
  ///
  /// Call [reauthenticate] immediately before this. Throws if anything fails;
  /// the caller shows the error and the account is left intact enough to try
  /// again, since every step is idempotent.
  Future<void> deleteAccount({
    required void Function(String step) onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final uid = user.uid;

    onProgress('جارٍ إزالة إعجاباتك…');
    await _removeAllLikes(uid);

    onProgress('جارٍ حذف مشاركاتك…');
    await _deleteOwnedDocs(
      _db.collection('communityMessages').where('authorUid', isEqualTo: uid),
    );

    onProgress('جارٍ حذف ملاحظاتك…');
    await _deleteOwnedDocs(
      _db.collection('feedbackMessages').where('authorUid', isEqualTo: uid),
    );

    onProgress('جارٍ حذف ملفك الشخصي…');
    await _deleteProfileAndUsername(user);

    onProgress('جارٍ إغلاق الحساب…');
    await user.delete();
  }

  /// Finds and removes every like this account left.
  ///
  /// This is a scan, not a query, and it has to be: a like doc is
  /// `{createdAt}` with the uid as its *document id*, and Firestore cannot
  /// filter a collection-group query by document id against a partial path.
  /// Adding a `uid` field would make future deletions a single query but
  /// would not find any like already written, so the scan stays.
  ///
  /// Cost is one read per visible message, once, at account deletion.
  Future<void> _removeAllLikes(String uid) async {
    final targets = <({String collection, String id})>[];

    // dailyMessages is world-readable; communityMessages is readable when
    // approved or authored by this user, so ask for exactly those two sets
    // rather than an unfiltered list the rules would reject.
    final daily = await _db.collection('dailyMessages').get();
    targets.addAll(
      daily.docs.map((d) => (collection: 'dailyMessages', id: d.id)),
    );

    final approved = await _db
        .collection('communityMessages')
        .where('status', isEqualTo: 'approved')
        .get();
    final own = await _db
        .collection('communityMessages')
        .where('authorUid', isEqualTo: uid)
        .get();
    final communityIds = {
      ...approved.docs.map((d) => d.id),
      ...own.docs.map((d) => d.id),
    };
    targets.addAll(
      communityIds.map((id) => (collection: 'communityMessages', id: id)),
    );

    for (var i = 0; i < targets.length; i += _probeBatch) {
      final slice = targets.skip(i).take(_probeBatch);
      final liked = await Future.wait(
        slice.map((t) async {
          final snap = await _db
              .collection(t.collection)
              .doc(t.id)
              .collection('likes')
              .doc(uid)
              .get();
          return snap.exists ? t : null;
        }),
      );

      for (final target in liked.whereType<({String collection, String id})>()) {
        // toggleLike on an existing like removes it and decrements the
        // parent's count in one transaction — the exact shape the rules
        // permit. Reusing it keeps this from drifting out of step with the
        // like path the rest of the app writes through.
        try {
          await _likes.toggleLike(target.collection, target.id);
        } catch (error) {
          // A single stubborn like should not strand the whole deletion:
          // the account and its identifying data still go, and a stray like
          // doc keyed by a uid that no longer resolves is inert.
          debugPrint('unlike ${target.collection}/${target.id} failed: $error');
        }
      }
    }
  }

  /// Deletes every doc a query returns, in chunks that respect Firestore's
  /// 500-write batch ceiling.
  Future<void> _deleteOwnedDocs(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;

    const chunk = 400;
    for (var i = 0; i < snapshot.docs.length; i += chunk) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Removes `users/{uid}` and releases the `usernames/` claim.
  ///
  /// The username key is derived the same way [AuthService] claims it, and
  /// the doc is checked before deleting: a name claimed by a *different* uid
  /// must not be released here, and the rules would deny it anyway.
  Future<void> _deleteProfileAndUsername(User user) async {
    final uid = user.uid;
    final profileRef = _db.collection('users').doc(uid);

    String? displayName = user.displayName;
    if (displayName == null || displayName.isEmpty) {
      // Fall back to the mirrored copy — a Google account that never set one
      // locally can still have a name recorded here.
      try {
        final snap = await profileRef.get();
        displayName = snap.data()?['displayName'] as String?;
      } catch (error) {
        debugPrint('reading users/$uid before delete failed: $error');
      }
    }

    if (displayName != null && displayName.isNotEmpty) {
      final key = AuthService.instance.normalizeDisplayName(displayName);
      if (key.isNotEmpty) {
        try {
          final nameRef = _db.collection('usernames').doc(key);
          final nameSnap = await nameRef.get();
          if (nameSnap.exists && nameSnap.data()?['uid'] == uid) {
            await nameRef.delete();
          }
        } catch (error) {
          // Losing the name release is a tidiness failure, not a privacy
          // one — the doc holds a uid that will no longer resolve. Never
          // worth aborting the deletion over.
          debugPrint('releasing usernames/$key failed: $error');
        }
      }
    }

    await profileRef.delete();
  }
}
