import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/arabic_numerals.dart';
import '../models/insight.dart';
import 'notification_scheduler.dart';

/// One of the signed-in reader's messages that a moderator has approved.
@immutable
class ApprovedSubmission {
  const ApprovedSubmission({required this.id, required this.message});

  final String id;
  final String message;
}

/// Everything [SubmissionApprovalWatcher] needs from Firestore, behind an
/// interface so tests can supply an in-memory fake — same reasoning as
/// NotificationDataSource.
abstract class SubmissionDataSource {
  /// The reader's approved messages, as the server has them right now.
  /// Throws if the server can't be reached — never answers from the cache,
  /// which can hold only some of them and would make the rest look new (or,
  /// on a first check, get them left out of what is recorded as already
  /// announced).
  Future<List<ApprovedSubmission>> loadApproved(String uid);

  /// Emits whenever one of the reader's pending messages stops being
  /// pending — approved, rejected or withdrawn, the caller finds out which.
  Stream<void> pendingDecided(String uid);
}

class FirestoreSubmissionDataSource implements SubmissionDataSource {
  FirestoreSubmissionDataSource([this._firestoreOverride]);

  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily rather than at construction, like
  // FirestoreNotificationDataSource: the watcher is built along with the app
  // widget, which a test can pump with no real Firestore behind it.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  // Two equality filters and no orderBy, so this needs no composite index.
  Query<Map<String, dynamic>> _mine(String uid, String status) => _db
      .collection('communityMessages')
      .where('authorUid', isEqualTo: uid)
      .where('status', isEqualTo: status);

  @override
  Future<List<ApprovedSubmission>> loadApproved(String uid) async {
    final snapshot = await _mine(uid, 'approved')
        .get(const GetOptions(source: Source.server))
        // Same deadline as CommunityService.refresh, for the same reason: a
        // server read can queue behind Firestore's own retries rather than
        // fail, which would otherwise hold up every check after it.
        .timeout(const Duration(seconds: 12));
    return [
      for (final doc in snapshot.docs)
        ApprovedSubmission(
          id: doc.id,
          message: doc.data()['message'] as String? ?? '',
        ),
    ];
  }

  // Deliberately the *pending* messages rather than all of the reader's own:
  // an approved post is updated every time someone likes it or a device shows
  // it, and each of those would be a billed read here for nothing.
  @override
  Stream<void> pendingDecided(String uid) => _mine(uid, 'pending')
      .snapshots()
      .where((snapshot) => snapshot.docChanges
          .any((change) => change.type == DocumentChangeType.removed))
      .map((_) {});
}

/// Tells a reader when a message they submitted has been approved, with a
/// local notification raised by the app itself. Dashboard approval needs no
/// part in this: it writes `status: 'approved'` as it always did, and this
/// reads that back.
///
/// There is no server to send a push (Spark plan, no Cloud Functions), so an
/// approval can only be noticed while the app is alive:
///
///   * running, even in the background — [SubmissionDataSource.pendingDecided]
///     catches it the moment it happens;
///   * closed — the check at start picks it up the next time the app opens.
///
/// Which approvals have been announced is kept per account on this device.
class SubmissionApprovalWatcher {
  SubmissionApprovalWatcher({
    SubmissionDataSource? dataSource,
    Stream<String?> Function()? uidChanges,
    Future<void> Function(List<ApprovedSubmission> approved)? notify,
  })  : _dataSource = dataSource ?? FirestoreSubmissionDataSource(),
        _uidChanges = uidChanges ?? _authUidChanges,
        _notify = notify ?? _showNotification;

  static const _seenKeyPrefix = 'submissionApprovals.seen.';

  final SubmissionDataSource _dataSource;
  final Stream<String?> Function() _uidChanges;
  final Future<void> Function(List<ApprovedSubmission> approved) _notify;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<void>? _pendingSub;
  String? _uid;
  Future<void>? _inFlight;

  static Stream<String?> _authUidChanges() =>
      FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);

  static Future<void> _showNotification(List<ApprovedSubmission> approved) {
    final text = approvalNotificationText(approved);
    return NotificationScheduler.instance
        .showSubmissionApproved(title: text.title, body: text.body);
  }

  /// Call once, from app start. `authStateChanges` emits the current state on
  /// listen, so a reader who is already signed in is checked straight away.
  void start() {
    _authSub = _uidChanges().listen(
      _onUserChanged,
      onError: (Object error) =>
          debugPrint('SubmissionApprovalWatcher: $error'),
    );
  }

  void dispose() {
    _authSub?.cancel();
    _pendingSub?.cancel();
  }

  void _onUserChanged(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _pendingSub?.cancel();
    _pendingSub = null;
    if (uid == null) return;

    _pendingSub = _dataSource.pendingDecided(uid).listen(
      (_) => check(),
      onError: (Object error) =>
          debugPrint('SubmissionApprovalWatcher: $error'),
    );
    check();
  }

  /// Announces whatever was approved since the last check. Never throws, and
  /// runs one at a time: at a cold start the check here and the listener's
  /// first event can land together, and must not both announce the same
  /// message.
  Future<void> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final approved = await _dataSource.loadApproved(uid);
      // Signed out or switched account during the read, so this list is no
      // longer the current reader's to announce.
      if (uid != _uid) return;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_seenKeyPrefix$uid';
      final fresh = unseenApprovals(approved, prefs.getStringList(key));
      if (fresh.isNotEmpty) await _notify(fresh);
      // After the notification, so one that failed is retried next time. The
      // price is a repeat if the app dies in between — which, being one fixed
      // notification id, replaces rather than adds to the first.
      await prefs.setStringList(key, [for (final s in approved) s.id]);
    } catch (error) {
      // Offline is the usual case here. Nothing was recorded, so the next
      // check picks up exactly where this one would have.
      debugPrint('SubmissionApprovalWatcher: $error');
    }
  }
}

/// Which of [approved] the reader still has to be told about.
///
/// A null [seen] means this device has never checked this account, so
/// everything approved so far is old news: it becomes the baseline rather than
/// an announcement, or a reinstall (or a new phone, or this very update) would
/// report messages approved long ago as if they had just happened.
List<ApprovedSubmission> unseenApprovals(
  List<ApprovedSubmission> approved,
  List<String>? seen,
) {
  if (seen == null) return const [];
  return approved.where((s) => !seen.contains(s.id)).toList();
}

/// What the notification says. Several approved at once share one
/// notification, so a batch review doesn't buzz the phone once per message.
/// Worded as a count to sidestep Arabic's dual and plural noun forms.
({String title, String body}) approvalNotificationText(
  List<ApprovedSubmission> approved,
) {
  if (approved.length == 1) {
    return (
      title: 'قُبلت رسالتك، جزاك الله خيراً',
      body: displayMessageText(approved.single.message),
    );
  }
  return (
    title: 'قُبلت رسائلك، جزاك الله خيراً',
    body: 'عدد الرسائل المقبولة: ${toArabicDigits(approved.length)}',
  );
}
