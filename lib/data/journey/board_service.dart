import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'journey_repository.dart';
import 'weekly_board.dart';

/// Where the board lives: the reader's own `scores/{uid}` and the published
/// `settings/weeklyBoard`.
abstract class BoardStore {
  /// The reader's entry, or null if they have not joined.
  Future<ScoreEntry?> ownScore(String uid);

  /// Replaces the reader's entry.
  Future<void> saveScore(ScoreEntry entry);

  /// Leaving removes the entry altogether.
  Future<void> removeScore(String uid);

  /// The last board a moderator published, or null before the first.
  Future<WeeklyBoard?> published();
}

class FirestoreBoardStore implements BoardStore {
  FirestoreBoardStore(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _score(String uid) =>
      _db.collection('scores').doc(uid);

  @override
  Future<ScoreEntry?> ownScore(String uid) async {
    final snap = await _score(uid).get();
    final data = snap.data();
    return data == null ? null : ScoreEntry.fromJson(uid, data);
  }

  @override
  Future<void> saveScore(ScoreEntry entry) => _score(entry.uid).set({
        ...entry.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> removeScore(String uid) => _score(uid).delete();

  @override
  Future<WeeklyBoard?> published() async {
    final snap = await _db.collection('settings').doc('weeklyBoard').get();
    final data = snap.data();
    if (data == null) return null;
    final at = data['publishedAt'];
    return WeeklyBoard.fromJson({
      ...data,
      'publishedAt': at is Timestamp ? at.toDate() : null,
    });
  }
}

class InMemoryBoardStore implements BoardStore {
  final Map<String, ScoreEntry> scores = {};
  WeeklyBoard? board;
  int writes = 0;

  @override
  Future<ScoreEntry?> ownScore(String uid) async => scores[uid];

  @override
  Future<void> saveScore(ScoreEntry entry) async {
    writes++;
    scores[entry.uid] = entry;
  }

  @override
  Future<void> removeScore(String uid) async => scores.remove(uid);

  @override
  Future<WeeklyBoard?> published() async => board;
}

/// Keeps a reader's board entry in step with their reading, while they have
/// chosen to be on the board. Nothing is sent for a reader who has not.
///
/// The phone works out its own points from the day log, as the journey tab
/// does, and replaces its entry. firestore.rules hold it to 300 a week, the
/// most an honest reader can earn on the phone, so claiming more gains
/// nothing.
class WeeklyBoardService {
  factory WeeklyBoardService() => _instance;
  WeeklyBoardService._();
  static final _instance = WeeklyBoardService._();

  BoardStore? _storeOverride;
  BoardStore? _firestore;
  BoardStore get _store =>
      _storeOverride ??
      (_firestore ??= FirestoreBoardStore(FirebaseFirestore.instance));

  String? Function() _displayName =
      () => FirebaseAuth.instance.currentUser?.displayName;

  /// Readings come in bursts; one write after they settle is enough.
  Duration _settle = const Duration(seconds: 5);

  JourneyRepository get _journey => JourneyRepository();

  /// The reader's entry while they are on the board, null otherwise.
  final ValueNotifier<ScoreEntry?> membership =
      ValueNotifier<ScoreEntry?>(null);

  /// The last published board, once [loadBoard] has fetched it.
  final ValueNotifier<WeeklyBoard?> board = ValueNotifier<WeeklyBoard?>(null);

  bool _started = false;
  String? _uid;
  int _generation = 0;
  Timer? _timer;

  /// What the store holds now, as far as this phone knows.
  ScoreEntry? _sent;

  void start() {
    if (_started) return;
    _started = true;
    _journey.listenable.addListener(_onJourney);
    _onJourney();
  }

  void _onJourney() {
    final uid = _journey.uid;
    if (uid != _uid) {
      unawaited(_bind(uid));
      return;
    }
    if (membership.value != null) _scheduleSync();
  }

  Future<void> _bind(String? uid) async {
    _uid = uid;
    _timer?.cancel();
    _sent = null;
    membership.value = null;
    final generation = ++_generation;
    if (uid == null) return;
    try {
      final own = await _store.ownScore(uid);
      if (generation != _generation) return;
      _sent = own;
      membership.value = own;
      if (own != null) _scheduleSync();
    } catch (error) {
      debugPrint('WeeklyBoardService: could not read the entry: $error');
    }
  }

  /// The entry as it should be now, or null when there is nothing to send.
  ScoreEntry? _current() {
    final uid = _uid;
    final own = membership.value;
    // Until the account's days arrive, the phone would send zero.
    if (uid == null || own == null || !_journey.accountLoaded) return null;
    return _entry(uid, useName: !own.anonymous, fallbackName: own.name);
  }

  ScoreEntry _entry(String uid,
          {required bool useName, String? fallbackName}) =>
      ScoreEntry(
        uid: uid,
        week: boardWeekOfDay(_journey.today),
        device: _journey.thisWeekPoints.device,
        name: boardName(
          useName: useName,
          displayName: _displayName() ?? fallbackName,
        ),
      );

  void _scheduleSync() {
    _timer?.cancel();
    _timer = Timer(_settle, () => unawaited(syncNow()));
  }

  /// Sends the entry now if it changed. Also run on a timer after readings.
  Future<void> syncNow() async {
    _timer?.cancel();
    final next = _current();
    if (next == null || next == _sent) return;
    _sent = next;
    membership.value = next;
    await _save(next);
  }

  /// Puts the reader on the board, under their name or as [kAnonymousName].
  /// False for a guest, who has no account to put there.
  bool join({required bool useName}) {
    final uid = _uid;
    if (uid == null) return false;
    final entry = _entry(uid, useName: useName);
    _sent = entry;
    membership.value = entry;
    unawaited(_save(entry));
    return true;
  }

  /// Takes the reader off the board. A board already published keeps the
  /// name until the next one replaces it.
  void leave() {
    final uid = _uid;
    if (uid == null) return;
    _timer?.cancel();
    _sent = null;
    membership.value = null;
    unawaited(_store.removeScore(uid).catchError((Object error) {
      debugPrint('WeeklyBoardService: could not leave: $error');
    }));
  }

  /// A write completes only when the server confirms it, which offline may
  /// be much later, so nothing waits on it.
  Future<void> _save(ScoreEntry entry) =>
      _store.saveScore(entry).catchError((Object error) {
        debugPrint('WeeklyBoardService: could not save: $error');
        // Try again on the next change rather than believing it was sent.
        if (identical(_sent, entry)) _sent = null;
      });

  /// Fetches the published board. Keeps the last one if this fails.
  Future<WeeklyBoard?> loadBoard() async {
    try {
      board.value = await _store.published();
    } catch (error) {
      debugPrint('WeeklyBoardService: could not load the board: $error');
    }
    return board.value;
  }

  @visibleForTesting
  Future<void> debugReset({
    BoardStore? store,
    String? Function()? displayName,
    Duration settle = const Duration(seconds: 5),
  }) async {
    if (_started) _journey.listenable.removeListener(_onJourney);
    _started = false;
    _timer?.cancel();
    _storeOverride = store;
    _displayName =
        displayName ?? () => FirebaseAuth.instance.currentUser?.displayName;
    _settle = settle;
    _uid = null;
    _sent = null;
    _generation++;
    membership.value = null;
    board.value = null;
  }
}
