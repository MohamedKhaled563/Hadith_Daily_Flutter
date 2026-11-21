import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_service.dart';

/// Feedback submitted from the settings drawer's "تواصل معنا واقترح فكرة"
/// sheet — saved to Firestore (rather than just handed to the OS share
/// sheet) so a moderator/admin can actually read it from the dashboard's
/// "تواصل معنا" tab.
class FeedbackService {
  FeedbackService._internal();
  static final FeedbackService instance = FeedbackService._internal();
  factory FeedbackService() => instance;

  static const _collection = 'feedbackMessages';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Throws if nobody is signed in — every screen that calls this already
  /// sits behind the app's sign-in gate at splash, so that should never
  /// actually happen in practice.
  ///
  /// Waits for the server no longer than [CommunityService.sendBudget].
  /// Offline, the write never answers, and awaiting it alone kept the form on
  /// «جارِ الإرسال...» for good (QA ISSUE-004). On
  /// [MessageDelivery.queued] the note is already in Firestore's queue and
  /// goes by itself, so the caller must not send it again.
  Future<MessageDelivery> submit({
    required String message,
    required String userName,
    required String userEmail,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to send feedback.');
    }

    return CommunityService.awaitDelivery(
      _db.collection(_collection).add({
        'authorUid': user.uid,
        'userName': userName,
        'userEmail': userEmail,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }
}
