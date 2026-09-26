import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a signed-in reader's favourites live: `users/{uid}/favorites/{id}`.
///
/// Favourites used to sit in SharedPreferences, which made them belong to the
/// phone rather than the person — two accounts on one phone shared a list,
/// signing out kept it, and a new phone started from whatever the OS backup
/// restored (or from the three hadiths the repository used to seed). They are
/// per account now, and a guest has none.
///
/// Kept behind this interface so tests can run the repository against an
/// in-memory store instead of Firestore.
abstract class FavoritesStore {
  /// Every favourite doc for [uid], re-emitted on each change. Local writes
  /// echo immediately (Firestore's latency compensation), so the list a
  /// reader sees never waits on the network.
  Stream<List<Map<String, dynamic>>> watch(String uid);

  Future<void> put(String uid, String docId, Map<String, dynamic> data);

  Future<void> remove(String uid, String docId);
}

class FirestoreFavoritesStore implements FavoritesStore {
  FirestoreFavoritesStore([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  @override
  Stream<List<Map<String, dynamic>>> watch(String uid) => _col(uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());

  @override
  Future<void> put(String uid, String docId, Map<String, dynamic> data) =>
      _col(uid).doc(docId).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> remove(String uid, String docId) =>
      _col(uid).doc(docId).delete();
}

/// Test double: one map per uid, re-emitted on every write.
class InMemoryFavoritesStore implements FavoritesStore {
  final _data = <String, Map<String, Map<String, dynamic>>>{};
  final _watchers =
      <String, Set<StreamController<List<Map<String, dynamic>>>>>{};
  var _clock = 0;

  List<Map<String, dynamic>> _snapshot(String uid) =>
      (_data[uid] ?? const {}).values.toList();

  void _emit(String uid) {
    for (final c in [...?_watchers[uid]]) {
      c.add(_snapshot(uid));
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watch(String uid) {
    // Asynchronous like Firestore: a test reading back what the store holds
    // (rather than the repository's optimistic state) pumps the event queue.
    late final StreamController<List<Map<String, dynamic>>> controller;
    controller = StreamController(
      onListen: () {
        (_watchers[uid] ??= {}).add(controller);
        controller.add(_snapshot(uid));
      },
      onCancel: () => _watchers[uid]?.remove(controller),
    );
    return controller.stream;
  }

  @override
  Future<void> put(String uid, String docId, Map<String, dynamic> data) async {
    (_data[uid] ??= {})[docId] = {...data, 'createdAt': _clock++};
    _emit(uid);
  }

  @override
  Future<void> remove(String uid, String docId) async {
    _data[uid]?.remove(docId);
    _emit(uid);
  }
}
