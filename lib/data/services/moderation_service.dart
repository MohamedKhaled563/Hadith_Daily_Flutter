import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why a reader flagged something. Stored as a stable key, not the Arabic
/// label, so the moderator dashboard can group reports without depending on
/// UI copy that may be reworded.
enum ReportReason {
  offensive,
  misattributed,
  spam,
  personalInfo,
  other,
}

extension ReportReasonKey on ReportReason {
  String get key => switch (this) {
        ReportReason.offensive => 'offensive',
        ReportReason.misattributed => 'misattributed',
        ReportReason.spam => 'spam',
        ReportReason.personalInfo => 'personal_info',
        ReportReason.other => 'other',
      };

  String get label => switch (this) {
        ReportReason.offensive => 'مسيء أو غير لائق',
        ReportReason.misattributed => 'منسوب للنبي ﷺ بغير علم',
        ReportReason.spam => 'إعلان أو خارج عن موضوع التطبيق',
        ReportReason.personalInfo => 'يحتوي بيانات شخصية',
        ReportReason.other => 'سبب آخر',
      };
}

/// Reporting a message, and hiding an author.
///
/// App Store guideline 1.2 requires any app carrying user-generated content
/// to offer a way to report objectionable content *and* to block abusive
/// users. The app had neither: submissions are moderated before they appear,
/// which covers intake, but nothing at all covered a post that is already
/// live.
///
/// The two halves work differently on purpose:
///
///  * **Reporting** is a server write, because a report is only useful if a
///    moderator sees it. It lands in `contentReports` with the reporter's uid
///    so the same account cannot spam the same post.
///  * **Blocking** is local to the device. Hiding an author is a personal
///    preference, not a moderation verdict, and keeping it in
///    SharedPreferences means it works for a guest, needs no rules, and
///    cannot leak who has blocked whom.
///
/// It is a [ChangeNotifier] because the block list is read by a screen that
/// does not own it: the community feed filters on it while building, but a
/// reader can change it from the settings drawer, two screens away. Without
/// the notification the feed kept its "everything here is hidden" empty state
/// after the author had already been unhidden — the control appeared to do
/// nothing until the tab was rebuilt for some unrelated reason.
class ModerationService extends ChangeNotifier {
  ModerationService._internal();
  static final ModerationService instance = ModerationService._internal();
  factory ModerationService() => instance;

  static const _collection = 'contentReports';
  static const _blockedKey = 'moderation.blockedAuthors';

  // Resolved on use, not on construction. Blocking is purely local, so a
  // reader — or a test — can touch this service with no Firebase behind it;
  // a field initializer would have thrown before either got the chance.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ------------------------------------------------------------ report ----

  /// Files a report. Throws if nobody is signed in — the caller gates on
  /// [requireSignIn] first, so a report always has someone behind it.
  Future<void> report({
    required String postId,
    required ReportReason reason,
    String note = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to report a message.');
    }

    // Doc id is `<postId>_<uid>`, so a second report of the same post by the
    // same reader overwrites the first rather than stacking. A moderator
    // sees one row per person who objected, which is the number that
    // actually means something.
    await _db.collection(_collection).doc('${postId}_${user.uid}').set({
      'postId': postId,
      'reporterUid': user.uid,
      'reason': reason.key,
      'note': note.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------- block ----

  Set<String> _blocked = <String>{};

  /// Loads the blocked list. Called at startup, before the feed builds.
  ///
  /// Re-reading is deliberately allowed rather than guarded by a `_loaded`
  /// flag: every write goes straight to disk, so disk is always the truth,
  /// and a second call simply re-syncs to it.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _blocked = (prefs.getStringList(_blockedKey) ?? const []).toSet();
    } catch (error) {
      // A prefs failure must not take the community feed down with it — an
      // empty block list shows more than intended, never less.
      debugPrint('blocked authors failed to load: $error');
    }
    notifyListeners();
  }

  Set<String> get blockedAuthors => Set.unmodifiable(_blocked);

  bool isBlocked(String authorName) => _blocked.contains(authorName);

  /// Hides or unhides an author.
  ///
  /// Keyed on the display name rather than the uid because that is what a
  /// [CommunityPost] carries — the feed never sees author uids, and widening
  /// the read rule to expose them would tell every reader who wrote what at
  /// the account level.
  Future<void> setBlocked(String authorName, bool blocked) async {
    if (authorName.trim().isEmpty) return;
    blocked ? _blocked.add(authorName) : _blocked.remove(authorName);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_blockedKey, _blocked.toList());
    } catch (error) {
      debugPrint('blocked authors failed to save: $error');
    }
    notifyListeners();
  }
}
