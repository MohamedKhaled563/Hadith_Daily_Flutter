import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// The reminder pool's change counter: `settings/notificationPool.version`.
///
/// NotificationScheduler keeps its own copy of `notificationMessages` and
/// goes back to the server only when this number has moved since its last
/// full fetch. Without it every device re-read the whole collection on every
/// refresh, up to one per resume every six hours — the same bill, for the
/// same reason, that [DailyPoolVersion] removed from the daily pool.
///
/// So anything that changes what is in the pool — adding, editing, switching
/// off or deleting a message — calls [bump]. A missed bump is not a
/// correctness hole, only a delay: the scheduler also refetches once its copy
/// is [NotificationScheduler.poolMaxAge] old. firestore.rules needs nothing
/// extra for this doc: everyone who can change the pool is a moderator or
/// admin, and those can already write any `settings/` doc.
class NotificationPoolVersion {
  NotificationPoolVersion._();

  static const field = 'version';

  /// The collection whose content [bump] stands for.
  static const collection = 'notificationMessages';

  static DocumentReference<Map<String, dynamic>> ref([FirebaseFirestore? db]) =>
      (db ?? FirebaseFirestore.instance)
          .collection('settings')
          .doc('notificationPool');

  /// Moves the version on by one.
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
      debugPrint('NotificationPoolVersion.bump failed: $error');
    }
  }
}
