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
  FirestoreNotificationDataSource([this._firestoreOverride]);

  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily rather than at construction: NotificationScheduler
  // builds this data source as soon as its singleton is first touched
  // (e.g. SplashScreen checking a cold-start notification tap), which can
  // happen before Firebase.initializeApp() has run — FirebaseFirestore.
  // instance would throw synchronously right there instead of only when a
  // message actually needs loading.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

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
