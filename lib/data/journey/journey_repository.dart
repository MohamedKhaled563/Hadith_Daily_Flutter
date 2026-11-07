import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_engine.dart';
import 'journey_models.dart';
import 'journey_store.dart';

/// What finishing a hadith added up to, for the completion sheet.
@immutable
class ReadingOutcome {
  const ReadingOutcome({
    required this.hadithNumber,
    required this.firstTime,
    required this.streak,
    required this.newBest,
    required this.completeCount,
    required this.days,
    this.milestone,
  });

  final int hadithNumber;

  /// False for a re-read, which keeps the streak but grows nothing.
  final bool firstTime;
  final StreakResult streak;

  /// Whether this reading made the longest streak longer.
  final bool newBest;
  final int completeCount;

  /// How many reading days have counted so far.
  final int days;

  /// The milestone just reached, if any.
  final int? milestone;
}

/// The reader's journey: what the screens read and what they report to.
///
/// A signed-in reader's journey lives in their account, so it follows them
/// to any phone and two accounts on one phone never see each other's. A guest
/// can read and grow a tree too, kept on the phone only, until they sign in
/// and it joins their account — the moment it gives them a reason to.
class JourneyRepository {
  JourneyRepository._internal();
  static final JourneyRepository _instance = JourneyRepository._internal();
  factory JourneyRepository() => _instance;

  static const _guestKey = 'journey.guest';

  JourneyStore? _storeOverride;
  JourneyStore? _defaultStore;
  // Built on first use: a guest never needs Firestore, and neither does a
  // widget test that only shows a screen.
  JourneyStore get _store =>
      _storeOverride ?? (_defaultStore ??= FirestoreJourneyStore());

  DateTime Function() _clock = DateTime.now;

  /// Swaps Firestore and the clock out for tests, and starts again as a guest.
  @visibleForTesting
  Future<void> debugReset({JourneyStore? store, DateTime Function()? clock}) {
    _storeOverride = store;
    _clock = clock ?? DateTime.now;
    _uid = null;
    _bound = false;
    return _bind(null);
  }

  String? _uid;
  bool _bound = false;
  int _generation = 0;
  int? _watchedYear;
  StreamSubscription<JourneyData>? _subscription;
  JourneyData _data = JourneyData.empty;

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Fires whenever the journey changes — a reading here, the account's data
  /// arriving after sign-in, or it clearing on sign-out.
  Listenable get listenable => _revision;

  JourneyData get data => _data;
  bool get isGuest => _uid == null;

  String get today => journeyDayKey(_clock());

  StreakResult get streak =>
      computeStreak(_data.days, today, storedBest: _data.bestStreak);

  DaySteps get todaySteps => DaySteps.of(_data, today);

  WeekCompare get weeks => WeekCompare.of(_data, today);

  int? get nextHadithNumber => nextHadith(_data, today);

  void _changed() => _revision.value++;

  /// Points the journey at [uid], or back to the phone for a guest.
  /// [AppStateController] calls this on every auth change.
  void setUser(String? uid) {
    if (_bound && uid == _uid) return;
    unawaited(_bind(uid));
  }

  Future<void> _bind(String? uid) async {
    final generation = ++_generation;
    _uid = uid;
    _bound = true;
    await _subscription?.cancel();
    _subscription = null;
    _watchedYear = null;
    _data = JourneyData.empty;
    _changed();

    final guest = await _loadGuest();
    if (generation != _generation) return;

    if (uid == null) {
      _data = guest;
      _changed();
      return;
    }

    if (!guest.isEmpty) {
      try {
        await _store.absorb(uid, guest);
        await _clearGuest();
      } catch (error) {
        // Left on the phone, to try again at the next sign-in.
        debugPrint('JourneyRepository: guest reading not moved: $error');
      }
      if (generation != _generation) return;
    }
    _watch(uid);
  }

  void _watch(String uid) {
    final year = _clock().year;
    _watchedYear = year;
    _subscription = _store.watch(uid, year).listen(
      (data) {
        if (_uid != uid) return;
        _data = data;
        _changed();
      },
      onError: (Object error) {
        debugPrint('JourneyRepository: journey for $uid failed: $error');
      },
    );
  }

  /// The app can stay open across New Year, and the days of the new year
  /// live in a doc nobody is watching yet.
  void _followYear() {
    final uid = _uid;
    if (uid == null || _watchedYear == null || _watchedYear == _clock().year) {
      return;
    }
    unawaited(_subscription?.cancel());
    _watch(uid);
  }

  Future<JourneyData> _loadGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_guestKey);
      if (stored == null) return JourneyData.empty;
      return JourneyData.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (error) {
      // A corrupt copy must never stop the app from opening.
      debugPrint('JourneyRepository: dropping guest journey: $error');
      return JourneyData.empty;
    }
  }

  Future<void> _saveGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_guestKey, jsonEncode(_data.toJson()));
    } catch (error) {
      debugPrint('JourneyRepository: guest journey not saved: $error');
    }
  }

  Future<void> _clearGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestKey);
  }

  /// Updates the screen at once, then saves. A rejected write is corrected
  /// by the next snapshot, which will not carry it.
  void _record(JourneyEvent event) {
    _followYear();
    var complete = event;
    if (_data.startedOn == null) {
      complete = complete.copyWith(startedOn: event.dayKey);
    }

    final after = _data.apply(complete);
    final best =
        computeStreak(after.days, event.dayKey, storedBest: after.bestStreak)
            .best;
    if (best > _data.bestStreak) complete = complete.copyWith(bestStreak: best);

    _data = _data.apply(complete);
    _changed();

    final uid = _uid;
    if (uid == null) {
      unawaited(_saveGuest());
    } else {
      unawaited(_store.record(uid, complete).catchError((Object error) {
        debugPrint('JourneyRepository: write failed: $error');
      }));
    }
  }

  /// The reader stayed with a message. [messageId] once per day is enough.
  void recordMessageRead(String messageId, {required int hadithNumber}) {
    final day = today;
    if (_data.days[day]?.messages.contains(messageId) ?? false) return;
    _record(JourneyEvent(
      dayKey: day,
      messageId: messageId,
      messageHadith: hadithNumber >= 1 ? hadithNumber : null,
    ));
  }

  /// The reader stayed long enough with a hadith's text and summary.
  void recordTextRead(int hadithNumber) {
    if (_data.progressOf(hadithNumber).textOn != null) return;
    _record(JourneyEvent(dayKey: today, textHadith: hadithNumber));
  }

  /// The reader finished a hadith's full explanation.
  ReadingOutcome recordFullRead(int hadithNumber, {required int seconds}) {
    final day = today;
    final before = streak;
    final firstTime = !_data.progressOf(hadithNumber).isComplete;
    final countAfter = _data.completeCount + (firstTime ? 1 : 0);

    final milestones = newMilestones(countAfter, _data.seen);
    _record(JourneyEvent(
      dayKey: day,
      fullHadith: hadithNumber,
      seconds: seconds,
      seen: [for (final m in milestones) milestoneId(m)],
    ));

    final after = streak;
    return ReadingOutcome(
      hadithNumber: hadithNumber,
      firstTime: firstTime,
      streak: after,
      newBest: after.current > before.best && after.current > 1,
      completeCount: countAfter,
      days: _data.days.values.where((d) => d.isPresent).length,
      milestone: milestones.isEmpty ? null : milestones.last,
    );
  }

  /// The reader sent a message to the community.
  void recordWrote() => _record(JourneyEvent(dayKey: today, wrote: 1));
}
