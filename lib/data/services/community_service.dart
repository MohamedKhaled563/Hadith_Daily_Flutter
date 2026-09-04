import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/insight.dart';

/// Firestore-backed community messages — submissions land as `pending` and
/// only become visible to everyone once a moderator approves them (phase 4;
/// until then, approval is done by hand in the Firebase console).
///
/// Likes here are an interim, honest-enough mechanism: a plain `likeCount`
/// field any signed-in reader may move by exactly one, with "have I already
/// liked this" tracked per-device in SharedPreferences. It can't stop the
/// same device liking twice after clearing local storage — phase 7 replaces
/// this with a real per-user `likes` subcollection that closes that gap.
class CommunityService {
  CommunityService._internal();
  static final CommunityService instance = CommunityService._internal();
  factory CommunityService() => instance;

  static const _collection = 'communityMessages';
  static const _likedIdsKey = 'community.likedMessageIds';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Set<String> _likedIds = {};
  bool _likedIdsLoaded = false;

  Future<void> _ensureLikedIdsLoaded() async {
    if (_likedIdsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _likedIds = (prefs.getStringList(_likedIdsKey) ?? const []).toSet();
    _likedIdsLoaded = true;
  }

  /// Synchronous best-effort check — returns false until the local liked-ids
  /// set has loaded once, which in practice has always happened by the time
  /// a post is on screen to be liked.
  bool isLiked(String messageId) => _likedIds.contains(messageId);

  CommunityPost _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return CommunityPost(
      id: doc.id,
      authorName: data['authorName'] as String? ?? 'فاعل خير',
      message: data['message'] as String? ?? '',
      hadithNumber: data['hadithNumber'] as int? ?? 0,
      likes: data['likeCount'] as int? ?? 0,
      isLiked: isLiked(doc.id),
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
        .asyncMap((snapshot) async {
      await _ensureLikedIdsLoaded();
      return snapshot.docs.map(_fromDoc).toList();
    });
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

  Future<void> toggleLike(String messageId) async {
    await _ensureLikedIdsLoaded();
    final ref = _db.collection(_collection).doc(messageId);
    final wasLiked = _likedIds.contains(messageId);

    if (wasLiked) {
      _likedIds.remove(messageId);
      await ref.update({'likeCount': FieldValue.increment(-1)});
    } else {
      _likedIds.add(messageId);
      await ref.update({'likeCount': FieldValue.increment(1)});
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_likedIdsKey, _likedIds.toList());
  }
}
