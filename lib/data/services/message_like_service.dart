import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Per-user, Firestore-backed likes for a message living in either
/// `dailyMessages` or `communityMessages` — the same pattern
/// [CommunityService.toggleLike] already uses for community posts, pulled
/// out so the daily-message screen (which shows cards from *either*
/// collection, see [DailyTipService]) can share it instead of the old
/// in-memory-only counters on HadithRepository, which reset on every app
/// restart and never left the device.
///
/// One doc per uid under `<collection>/<messageId>/likes/{uid}` — its mere
/// existence is "have I liked this" — plus a denormalised `likeCount` on the
/// message itself for cheap display, kept in sync via [FieldValue.increment]
/// inside the same transaction as the like doc.
class MessageLikeService {
  MessageLikeService._internal();
  static final MessageLikeService instance = MessageLikeService._internal();
  factory MessageLikeService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live "have I liked this", following whoever is signed in.
  ///
  /// This used to read `currentUser` once, when the stream was made, and
  /// hand back a permanent `false` for nobody. Screens hold these streams for
  /// their whole life, and at a cold start the home screen builds every tab,
  /// the community feed included, a moment before Firebase has restored the
  /// saved sign-in. Those cards stayed "not liked" for good: like a post from
  /// its detail screen, come back, and the feed showed the new count beside a
  /// white heart; tapping it sent a second like, which the rules rejected.
  /// Signing in from the "sign in to like" sheet hit the same wall.
  ///
  /// So it re-subscribes on every sign-in and sign-out instead.
  Stream<bool> likeStatus(String collection, String messageId) {
    return followingUser(
      () => FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
      (uid) {
        if (uid == null) return Stream.value(false);
        return _db
            .collection(collection)
            .doc(messageId)
            .collection('likes')
            .doc(uid)
            .snapshots()
            .map((doc) => doc.exists);
      },
    );
  }

  /// [build]'s stream for the current user, swapped for a fresh one whenever
  /// [users] names someone else. `authStateChanges` emits the current state
  /// on listen, so the first value never waits for a change.
  ///
  /// Each listener gets its own subscriptions, so a stream a screen holds
  /// can be listened to again, as Firestore's own streams can.
  @visibleForTesting
  static Stream<T> followingUser<T>(
    Stream<String?> Function() users,
    Stream<T> Function(String? uid) build,
  ) {
    return Stream<T>.multi((controller) {
      StreamSubscription<T>? inner;
      var started = false;
      String? current;

      final auth = users().listen((uid) {
        if (started && uid == current) return;
        started = true;
        current = uid;
        inner?.cancel();
        inner = build(uid).listen(
          controller.add,
          onError: controller.addError,
        );
      }, onError: controller.addError);

      controller
        ..onPause = () {
          auth.pause();
          inner?.pause();
        }
        ..onResume = () {
          auth.resume();
          inner?.resume();
        }
        ..onCancel = () async {
          await inner?.cancel();
          await auth.cancel();
        };
    });
  }

  Stream<int> likeCount(String collection, String messageId) {
    return _db
        .collection(collection)
        .doc(messageId)
        .snapshots()
        .map((doc) => (doc.data()?['likeCount'] as num?)?.toInt() ?? 0);
  }

  /// Likes or unlikes [messageId], as a plain batch rather than a
  /// transaction — the like buttons' path.
  ///
  /// A batch lands in the local cache the moment it is issued, so the
  /// [likeStatus]/[likeCount] streams echo it within a frame, and it queues
  /// while offline instead of failing. A transaction does neither: it is
  /// never applied locally ahead of the server, and offline it fails
  /// outright with `unavailable` — the heart did nothing, then snapped back.
  ///
  /// [liked] is the state the reader is asking for, which the caller already
  /// knows from [likeStatus]. firestore.rules checks it against the like doc
  /// as it stood before the write, so a batch built from a stale view is
  /// rejected rather than moving the counter the wrong way.
  ///
  /// The returned future settles only on the server's answer — offline, not
  /// until the device reconnects — so callers should not hold UI on it; it is
  /// there to surface a rejection.
  Future<void> setLiked(String collection, String messageId,
      {required bool liked}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Future.error(StateError('Must be signed in to like a message.'));
    }

    final messageRef = _db.collection(collection).doc(messageId);
    final likeRef = messageRef.collection('likes').doc(user.uid);
    final batch = _db.batch();
    if (liked) {
      batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(messageRef, {'likeCount': FieldValue.increment(1)});
    } else {
      batch.delete(likeRef);
      batch.update(messageRef, {'likeCount': FieldValue.increment(-1)});
    }
    return batch.commit();
  }

  /// Flips the like from whatever the server says it is now. Still a
  /// transaction: AccountDeletionService needs the server's answer before it
  /// moves on, and has no stream of its own to read the current state from.
  Future<void> toggleLike(String collection, String messageId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to like a message.');
    }

    final messageRef = _db.collection(collection).doc(messageId);
    final likeRef = messageRef.collection('likes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(messageRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(messageRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }
}
