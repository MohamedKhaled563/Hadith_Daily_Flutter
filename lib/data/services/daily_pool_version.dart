import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// The daily-message pool's change counter: `settings/dailyPool.version`.
///
/// DailyTipService reads the pool — every `dailyMessages` doc plus every
/// approved `communityMessages` one — from Firestore's local cache, which
/// costs no reads, and goes back to the server only when this number has
/// moved since its last full fetch. Without it every device re-read the
/// whole pool every day, a bill that grows with the pool times the readers
/// on a free-tier project.
///
/// So anything that changes what is *in* the pool — adding, editing or
/// deleting a daily message, approving or hiding a community one, deleting
/// an account's posts — calls [bump]. Counters on a message (likeCount,
/// timesShown) are not content and do not. A missed bump is not a
/// correctness hole, only a delay: DailyTipService also refetches once its
/// copy is a week old, and whenever today's pinned message is missing from
/// it.
class DailyPoolVersion {
  DailyPoolVersion._();

  static const field = 'version';

  static DocumentReference<Map<String, dynamic>> ref([FirebaseFirestore? db]) =>
      (db ?? FirebaseFirestore.instance)
          .collection('settings')
          .doc('dailyPool');

  /// The collections whose content [bump] stands for.
  static const collections = {'dailyMessages', 'communityMessages'};

  /// Moves the version on by one. firestore.rules lets any signed-in user do
  /// exactly that and nothing else — account deletion runs as the account
  /// being deleted, not a moderator.
  ///
  /// Best effort and never throws: the write it follows has already
  /// succeeded, and failing it over a cache hint would be backwards.
  static Future<void> bump() async {
    try {
      await ref().set(
        {field: FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('DailyPoolVersion.bump failed: $error');
    }
  }
}
