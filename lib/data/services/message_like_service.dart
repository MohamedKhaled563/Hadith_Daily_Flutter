import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Stream<bool> likeStatus(String collection, String messageId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return _db
        .collection(collection)
        .doc(messageId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<int> likeCount(String collection, String messageId) {
    return _db
        .collection(collection)
        .doc(messageId)
        .snapshots()
        .map((doc) => (doc.data()?['likeCount'] as num?)?.toInt() ?? 0);
  }

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
