import 'package:cloud_firestore/cloud_firestore.dart';

/// Everything NotificationScheduler needs from Firestore, behind an
/// interface so tests can supply an in-memory fake instead of talking to a
/// real (or emulated) Firestore instance.
abstract class NotificationDataSource {
  /// Raw `notificationMessages` docs where `active == true`.
  Future<List<Map<String, dynamic>>> loadActiveMessages();

  /// `settings/notificationMode` — always resolves to 'manual' or 'random',
  /// defaulting to 'random' when the doc is missing or unreadable.
  Future<String> loadMode();
}

class FirestoreNotificationDataSource implements NotificationDataSource {
  FirestoreNotificationDataSource([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async {
    final snapshot = await _db
        .collection('notificationMessages')
        .where('active', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<String> loadMode() async {
    try {
      final doc =
          await _db.collection('settings').doc('notificationMode').get();
      return doc.data()?['mode'] == 'manual' ? 'manual' : 'random';
    } catch (_) {
      return 'random';
    }
  }
}
