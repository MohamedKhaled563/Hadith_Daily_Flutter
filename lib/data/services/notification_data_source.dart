import 'package:cloud_firestore/cloud_firestore.dart';

/// Everything NotificationScheduler needs from Firestore, behind an
/// interface so tests can supply an in-memory fake instead of talking to a
/// real (or emulated) Firestore instance.
abstract class NotificationDataSource {
  /// Raw `notificationMessages` docs where `active == true`.
  Future<List<Map<String, dynamic>>> loadActiveMessages();

  // There was a `loadMode` here too, reading `settings/notificationMode`
  // ('manual' | 'random'). The dashboard no longer offers that toggle — the
  // day-by-day curation lives on the daily-message calendar instead — so
  // reminders are always drawn at random; see pickMessageForDay.

  // There was a `loadMessageById` here, for resolving a tapped notification
  // back to the notificationMessages doc its payload named. Nothing has
  // called it since tapping a reminder was changed to open *today's actual
  // message* instead — see NotificationScheduler.notificationTapped — so it
  // was an unused Firestore read path kept alive only by this interface.
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
    // The doc id rides along as 'id' so a tapped notification's payload can
    // resolve back to this exact doc — the id isn't part of doc.data().
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

}
