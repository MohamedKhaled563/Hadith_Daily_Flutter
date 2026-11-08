import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'journey_models.dart';
import 'memorization.dart';

/// Where a signed-in reader's journey lives:
/// `users/{uid}/journey/state` and `users/{uid}/journeyYears/{yyyy}`.
///
/// Two small documents per reader, under the account, so the journey follows
/// the person to any phone. One document for all 42 hadiths costs one read,
/// where one per hadith would cost 42; the days sit in a yearly document so
/// the small one stays small.
///
/// Kept behind this interface so tests can run the repository against an
/// in-memory store instead of Firestore, same as FavoritesStore.
abstract class JourneyStore {
  /// The reader, re-emitted on each change. Local writes echo immediately
  /// (Firestore's latency compensation), offline included. Holds [year] and
  /// the one before, which is enough for a streak running over New Year.
  Stream<JourneyData> watch(String uid, int year);

  /// Records [event]. Writes merge field by field and repeat safely, so two
  /// phones offline cannot erase each other's progress.
  Future<void> record(String uid, JourneyEvent event);

  /// Folds a guest's reading into the account, once, at sign-in.
  Future<void> absorb(String uid, JourneyData guest);

  /// Replaces the reader's reminder settings.
  Future<void> savePrefs(String uid, ReminderPrefs prefs);
}

class FirestoreJourneyStore implements JourneyStore {
  FirestoreJourneyStore([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _state(String uid) =>
      _user(uid).collection('journey').doc('state');

  DocumentReference<Map<String, dynamic>> _year(String uid, String year) =>
      _user(uid).collection('journeyYears').doc(year);

  @override
  Stream<JourneyData> watch(String uid, int year) {
    final subscriptions = <StreamSubscription<void>>[];
    late final StreamController<JourneyData> controller;

    Map<String, dynamic>? state;
    Map<String, dynamic>? thisYear;
    Map<String, dynamic>? lastYear;

    void emit() {
      final s = state, current = thisYear, previous = lastYear;
      if (s == null || current == null || previous == null) return;
      controller.add(JourneyData.fromDocs(s, [previous, current]));
    }

    controller = StreamController<JourneyData>(
      onListen: () {
        subscriptions.addAll([
          _state(uid).snapshots().listen((snap) {
            state = snap.data() ?? const {};
            emit();
          }, onError: controller.addError),
          _year(uid, '$year').snapshots().listen((snap) {
            thisYear = snap.data() ?? const {};
            emit();
          }, onError: controller.addError),
          _year(uid, '${year - 1}').snapshots().listen((snap) {
            lastYear = snap.data() ?? const {};
            emit();
          }, onError: controller.addError),
        ]);
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        // Nobody is listening any more, and a new watch makes a new one.
        await controller.close();
      },
    );
    return controller.stream;
  }

  Map<String, dynamic> _stateUpdate(
    JourneyEvent event,
  ) {
    final hadith = <String, dynamic>{};
    final text = event.textHadith;
    if (text != null) hadith['$text'] = {'text': event.dayKey};
    final full = event.fullHadith;
    if (full != null) {
      hadith['$full'] = {
        'full': event.dayKey,
        'reads': FieldValue.increment(1),
      };
    }

    final memoHadith = event.memoHadith;
    final memo = event.memo;

    return {
      'v': 1,
      'updatedAt': FieldValue.serverTimestamp(),
      if (event.startedOn != null) 'startedOn': event.startedOn,
      if (hadith.isNotEmpty) 'hadith': hadith,
      if (memoHadith != null && memo != null)
        'memo': {'$memoHadith': _memoFields(memo)},
      if (event.seen.isNotEmpty) 'seen': FieldValue.arrayUnion(event.seen),
      if (event.bestStreak != null) 'records': {'bestStreak': event.bestStreak},
    };
  }

  /// Every field of [memo], with the ones it no longer has deleted: a merge
  /// would otherwise keep an old `due` after the hadith is kept.
  static Map<String, dynamic> _memoFields(MemoProgress memo) {
    final json = memo.toJson();
    return {
      for (final key in const ['parts', 'box', 'due', 'misses', 'on'])
        key: json[key] ?? FieldValue.delete(),
    };
  }

  Map<String, dynamic> _dayUpdate(JourneyEvent event) => {
        'days': {
          event.dayKey: {
            if (event.messageId != null)
              'm': FieldValue.arrayUnion([event.messageId]),
            if (event.messageHadith != null) 'mh': event.messageHadith,
            if (event.fullHadith != null)
              'h': FieldValue.arrayUnion([event.fullHadith]),
            if (event.seconds > 0) 's': FieldValue.increment(event.seconds),
            if (event.wrote > 0) 'w': FieldValue.increment(event.wrote),
            if (event.communityId != null)
              'c': FieldValue.arrayUnion([event.communityId]),
            if (event.shared > 0) 'x': FieldValue.increment(event.shared),
            if (event.memoPart && event.memoHadith != null)
              'p': FieldValue.arrayUnion([event.memoHadith]),
            if (event.memorized && event.memoHadith != null)
              'mz': FieldValue.arrayUnion([event.memoHadith]),
            if (event.reviewed && event.memoHadith != null)
              'r': FieldValue.arrayUnion([event.memoHadith]),
          },
        },
      };

  @override
  Future<void> record(String uid, JourneyEvent event) {
    final batch = _db.batch()
      ..set(_state(uid), _stateUpdate(event), SetOptions(merge: true));
    final isDayEvent = event.messageId != null ||
        event.fullHadith != null ||
        event.seconds > 0 ||
        event.wrote > 0 ||
        event.communityId != null ||
        event.shared > 0 ||
        event.memoPart ||
        event.memorized ||
        event.reviewed;
    if (isDayEvent) {
      batch.set(
        _year(uid, event.dayKey.substring(0, 4)),
        _dayUpdate(event),
        SetOptions(merge: true),
      );
    }
    return batch.commit();
  }

  @override
  Future<void> absorb(String uid, JourneyData guest) async {
    // Anything the account already has stands: its dates are the older ones.
    final existing = await _existingState(uid);
    final hadith = <String, dynamic>{};
    for (final entry in guest.hadith.entries) {
      final known = existing.progressOf(entry.key);
      hadith['${entry.key}'] = {
        if (known.textOn == null && entry.value.textOn != null)
          'text': entry.value.textOn,
        if (known.fullOn == null && entry.value.fullOn != null)
          'full': entry.value.fullOn,
        if (entry.value.reads > 0)
          'reads': FieldValue.increment(entry.value.reads),
      };
    }

    // Memorization the account already has stands; the guest's fills gaps.
    final memo = <String, dynamic>{
      for (final entry in guest.memo.entries)
        if (!existing.memo.containsKey(entry.key))
          '${entry.key}': entry.value.toJson(),
    };

    final batch = _db.batch()
      ..set(
        _state(uid),
        {
          'v': 1,
          'updatedAt': FieldValue.serverTimestamp(),
          if (existing.startedOn == null && guest.startedOn != null)
            'startedOn': guest.startedOn,
          if (hadith.isNotEmpty) 'hadith': hadith,
          if (memo.isNotEmpty) 'memo': memo,
          if (guest.seen.isNotEmpty)
            'seen': FieldValue.arrayUnion(guest.seen.toList()),
        },
        SetOptions(merge: true),
      );

    final byYear = <String, Map<String, JourneyDay>>{};
    for (final entry in guest.days.entries) {
      (byYear[entry.key.substring(0, 4)] ??= {})[entry.key] = entry.value;
    }
    for (final year in byYear.entries) {
      batch.set(
        _year(uid, year.key),
        {
          'days': {
            for (final day in year.value.entries)
              day.key: {
                if (day.value.messages.isNotEmpty)
                  'm': FieldValue.arrayUnion(day.value.messages),
                if (day.value.messageHadith != null)
                  'mh': day.value.messageHadith,
                if (day.value.hadiths.isNotEmpty)
                  'h': FieldValue.arrayUnion(day.value.hadiths),
                if (day.value.seconds > 0)
                  's': FieldValue.increment(day.value.seconds),
                if (day.value.wrote > 0)
                  'w': FieldValue.increment(day.value.wrote),
                if (day.value.community.isNotEmpty)
                  'c': FieldValue.arrayUnion(day.value.community),
                if (day.value.shared > 0)
                  'x': FieldValue.increment(day.value.shared),
                if (day.value.memoParts.isNotEmpty)
                  'p': FieldValue.arrayUnion(day.value.memoParts),
                if (day.value.memorized.isNotEmpty)
                  'mz': FieldValue.arrayUnion(day.value.memorized),
                if (day.value.reviewed.isNotEmpty)
                  'r': FieldValue.arrayUnion(day.value.reviewed),
              },
          },
        },
        SetOptions(merge: true),
      );
    }
    // Not awaited to the server: offline, a commit waits for the connection
    // but is already safe in Firestore's queue, and that is enough to clear
    // the guest copy.
    unawaited(batch.commit());
  }

  @override
  Future<void> savePrefs(String uid, ReminderPrefs prefs) => _state(uid).set(
        {
          'v': 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'prefs': prefs.toJson(),
        },
        SetOptions(merge: true),
      );

  Future<JourneyData> _existingState(String uid) async {
    try {
      final snap = await _state(uid).get();
      return JourneyData.fromDocs(snap.data() ?? const {}, const []);
    } catch (_) {
      return JourneyData.empty;
    }
  }
}

/// Test double: one reader per uid, re-emitted on every write.
class InMemoryJourneyStore implements JourneyStore {
  final _data = <String, JourneyData>{};
  final _watchers = <String, Set<StreamController<JourneyData>>>{};

  JourneyData dataOf(String uid) => _data[uid] ?? JourneyData.empty;

  void _emit(String uid) {
    for (final controller in [...?_watchers[uid]]) {
      controller.add(dataOf(uid));
    }
  }

  @override
  Stream<JourneyData> watch(String uid, int year) {
    // Asynchronous like Firestore: a test reading back what the store holds
    // pumps the event queue.
    late final StreamController<JourneyData> controller;
    controller = StreamController(
      onListen: () {
        (_watchers[uid] ??= {}).add(controller);
        controller.add(dataOf(uid));
      },
      onCancel: () => _watchers[uid]?.remove(controller),
    );
    return controller.stream;
  }

  @override
  Future<void> record(String uid, JourneyEvent event) async {
    _data[uid] = dataOf(uid).apply(event);
    _emit(uid);
  }

  @override
  Future<void> savePrefs(String uid, ReminderPrefs prefs) async {
    _data[uid] = dataOf(uid).withPrefs(prefs);
    _emit(uid);
  }

  @override
  Future<void> absorb(String uid, JourneyData guest) async {
    final account = dataOf(uid);
    final hadith = Map<int, HadithProgress>.of(account.hadith);
    for (final entry in guest.hadith.entries) {
      final known = hadith[entry.key] ?? const HadithProgress();
      hadith[entry.key] = HadithProgress(
        textOn: known.textOn ?? entry.value.textOn,
        fullOn: known.fullOn ?? entry.value.fullOn,
        reads: known.reads + entry.value.reads,
      );
    }
    final days = Map<String, JourneyDay>.of(account.days);
    for (final entry in guest.days.entries) {
      final known = days[entry.key] ?? const JourneyDay();
      days[entry.key] = JourneyDay(
        messages: {...known.messages, ...entry.value.messages}.toList(),
        messageHadith: entry.value.messageHadith ?? known.messageHadith,
        hadiths: {...known.hadiths, ...entry.value.hadiths}.toList(),
        seconds: known.seconds + entry.value.seconds,
        wrote: known.wrote + entry.value.wrote,
        community: {...known.community, ...entry.value.community}.toList(),
        shared: known.shared + entry.value.shared,
        memoParts: {...known.memoParts, ...entry.value.memoParts}.toList(),
        memorized: {...known.memorized, ...entry.value.memorized}.toList(),
        reviewed: {...known.reviewed, ...entry.value.reviewed}.toList(),
      );
    }
    _data[uid] = JourneyData(
      startedOn: account.startedOn ?? guest.startedOn,
      hadith: hadith,
      days: days,
      seen: {...account.seen, ...guest.seen},
      bestStreak: account.bestStreak,
      prefs: account.prefs,
      memo: {...guest.memo, ...account.memo},
    );
    _emit(uid);
  }
}
