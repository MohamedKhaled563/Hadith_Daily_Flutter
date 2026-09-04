import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/insight.dart';

/// Firestore-backed community messages — submissions land as `pending` and
/// only become visible to everyone once a moderator approves them (phase 4;
/// until then, approval is done by hand in the Firebase console).
///
/// Likes are tracked per-user in a `likes` subcollection (one doc per uid,
/// keyed by uid so a second like from the same account is just overwriting
/// its own doc rather than double-counting) alongside a denormalised
/// `likeCount` on the message for cheap sorting/display.
class CommunityService {
  CommunityService._internal();
  static final CommunityService instance = CommunityService._internal();
  factory CommunityService() => instance;

  static const _collection = 'communityMessages';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CommunityPost _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return CommunityPost(
      id: doc.id,
      authorName: data['authorName'] as String? ?? 'فاعل خير',
      message: data['message'] as String? ?? '',
      hadithNumber: data['hadithNumber'] as int? ?? 0,
      likes: data['likeCount'] as int? ?? 0,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  /// Live query of every approved message, newest first. Rebuilds
  /// automatically the moment a moderator approves something new.
  Stream<List<CommunityPost>> approvedMessages() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  /// Throws if nobody is signed in — every screen that calls this already
  /// sits behind the app's sign-in gate at splash, so that should never
  /// actually happen in practice.
  Future<void> submit({
    required int hadithNumber,
    required String message,
    required String authorName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to submit a community message.');
    }

    await _db.collection(_collection).add({
      'authorUid': user.uid,
      'authorName': authorName,
      'hadithNumber': hadithNumber,
      'message': message,
      'status': 'pending',
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live count of every message the signed-in user has ever submitted,
  /// any status — used for the "مشاركاتي" stat on the profile drawer.
  Stream<int> myContributionsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return _db
        .collection(_collection)
        .where('authorUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Live "have I liked this" status for the signed-in user, sourced
  /// straight from their own `likes/{uid}` doc rather than a local cache —
  /// stays correct across devices and survives clearing local storage.
  Stream<bool> likeStatus(String messageId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return _db
        .collection(_collection)
        .doc(messageId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike(String messageId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to like a message.');
    }

    final postRef = _db.collection(_collection).doc(messageId);
    final likeRef = postRef.collection('likes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }
}
