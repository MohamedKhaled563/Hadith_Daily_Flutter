import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_engine.dart';
import 'journey_models.dart';
import 'journey_points.dart';
import 'journey_store.dart';
import 'memorization.dart' as memorization show dueReviews;
import 'memorization.dart';

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
    this.record,
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

  /// A personal record this reading beat, if any.
  final JourneyRecord? record;
}

/// What learning a part added up to, for the memorization sheet.
@immutable
class MemoOutcome {
  const MemoOutcome({
    required this.hadithNumber,
    required this.progress,
    required this.totalParts,
    required this.memorizedCount,
    this.milestone,
  });

  final int hadithNumber;
  final MemoProgress progress;
  final int totalParts;
  final int memorizedCount;

  /// A memorization milestone this reached, if any — see [kMemoMilestones].
  final int? milestone;

  bool get memorized => progress.isMemorized;
}

/// What a review added up to.
@immutable
class ReviewOutcome {
  const ReviewOutcome({
    required this.hadithNumber,
    required this.progress,
    required this.counted,
    required this.remembered,
  });

  final int hadithNumber;
  final MemoProgress progress;

  /// False for a review that was not due yet: practice, nothing recorded.
  final bool counted;
  final bool remembered;
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

  /// Whether this account's own data has arrived yet. Until then [data] is
  /// empty because nothing has loaded, not because the reader has done nothing.
  bool _accountLoaded = false;

  /// The same for a guest, whose journey is read from the phone.
  bool _guestLoaded = false;

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Fires whenever the journey changes — a reading here, the account's data
  /// arriving after sign-in, or it clearing on sign-out.
  Listenable get listenable => _revision;

  JourneyData get data => _data;
  bool get isGuest => _uid == null;
  String? get uid => _uid;
  bool get accountLoaded => _uid != null && _accountLoaded;

  /// Whether [data] is the reader's own yet, guest or account.
  bool get loaded => _uid == null ? _guestLoaded : _accountLoaded;

  String get today => journeyDayKey(_clock());

  StreakResult get streak =>
      computeStreak(_data.days, today, storedBest: _data.bestStreak);

  DaySteps get todaySteps => DaySteps.of(_data, today);

  WeekCompare get weeks => WeekCompare.of(_data, today);

  int? get nextHadithNumber => nextHadith(_data, today);

  /// The reading day each of this reader's messages was approved on. Not
  /// stored with the journey: it comes from the messages themselves, read by
  /// SubmissionApprovalWatcher.
  List<String> _approvedOn = const [];
  List<String> get approvedOn => _approvedOn;

  /// [uid]'s approved messages, as the server last reported them.
  void setApprovedOn(String uid, List<String> dayKeys) {
    if (uid != _uid) return;
    _approvedOn = List.unmodifiable(dayKeys);
    _changed();
  }

  WeekPoints get thisWeekPoints =>
      weekPoints(_data, weekStartKey(today), approvedOn: _approvedOn);

  WeekPoints get lastWeekPoints => weekPoints(
        _data,
        dayKeyPlus(weekStartKey(today), -7),
        approvedOn: _approvedOn,
      );

  /// The most days in a row this week, up to today.
  int get bestThisWeek => bestRunInWeek(_data, weekStartKey(today), today);

  /// Every point earned, each week capped as on the board.
  int get allPoints => totalPoints(_data, approvedOn: _approvedOn);

  Map<JourneyRecord, int> get records =>
      journeyRecords(_data, today: today, approvedOn: _approvedOn);

  Map<JourneyRecord, RecordStanding> get _standings =>
      recordStandings(_data, today: today, approvedOn: _approvedOn);

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
    _accountLoaded = false;
    _guestLoaded = false;
    _approvedOn = const [];
    _data = JourneyData.empty;
    _changed();

    final guest = await _loadGuest();
    if (generation != _generation) return;

    if (uid == null) {
      _data = guest;
      _guestLoaded = true;
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
        _accountLoaded = true;
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
    final recordsBefore = _standings;
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
      record: brokenRecord(recordsBefore, _standings),
    );
  }

  /// The hadiths due for review today, the longest waiting first.
  List<int> get dueReviews => memorization.dueReviews(_data.memo, today);

  /// One more part of [hadithNumber] learned by heart, out of [totalParts].
  /// The last part makes it memorized. Nothing changes for a hadith already
  /// memorized.
  MemoOutcome learnPart(int hadithNumber, {required int totalParts}) {
    final day = today;
    final before = _data.memoOf(hadithNumber);
    if (before.isMemorized) {
      return MemoOutcome(
        hadithNumber: hadithNumber,
        progress: before,
        totalParts: totalParts,
        memorizedCount: _data.memorizedCount,
      );
    }
    final after = afterPartLearned(before, totalParts: totalParts, today: day);
    final memorized = after.isMemorized;
    final count = _data.memorizedCount + (memorized ? 1 : 0);
    final milestones =
        memorized ? newMemoMilestones(count, _data.seen) : const <int>[];
    _record(JourneyEvent(
      dayKey: day,
      memoHadith: hadithNumber,
      memo: after,
      memoPart: !memorized,
      memorized: memorized,
      seen: [for (final m in milestones) memoMilestoneId(m)],
    ));
    return MemoOutcome(
      hadithNumber: hadithNumber,
      progress: after,
      totalParts: totalParts,
      memorizedCount: count,
      milestone: milestones.isEmpty ? null : milestones.last,
    );
  }

  /// A review of [hadithNumber]. Only a review that is due moves it on or
  /// back; reciting one early is practice, and changes nothing.
  ReviewOutcome review(int hadithNumber, {required bool remembered}) {
    final day = today;
    final before = _data.memoOf(hadithNumber);
    if (!before.isDue(day)) {
      return ReviewOutcome(
        hadithNumber: hadithNumber,
        progress: before,
        counted: false,
        remembered: remembered,
      );
    }
    final after = afterReview(before, remembered: remembered, today: day);
    _record(JourneyEvent(
      dayKey: day,
      memoHadith: hadithNumber,
      memo: after,
      reviewed: true,
    ));
    return ReviewOutcome(
      hadithNumber: hadithNumber,
      progress: after,
      counted: true,
      remembered: remembered,
    );
  }

  /// The reader stayed with a community post. Once per post per day.
  void recordCommunityRead(String postId) {
    final day = today;
    if (_data.days[day]?.community.contains(postId) ?? false) return;
    _record(JourneyEvent(dayKey: day, communityId: postId));
  }

  /// The reader shared a card outside the app.
  void recordShared() => _record(JourneyEvent(dayKey: today, shared: 1));

  /// The reader sent a message to the community.
  void recordWrote() => _record(JourneyEvent(dayKey: today, wrote: 1));

  /// Keeps the reader's reminder settings with their account. A guest's stay
  /// on the phone.
  void saveReminderPrefs(ReminderPrefs prefs) {
    final uid = _uid;
    if (uid == null || _data.prefs == prefs) return;
    _data = _data.withPrefs(prefs);
    _changed();
    unawaited(_store.savePrefs(uid, prefs).catchError((Object error) {
      debugPrint('JourneyRepository: reminder settings not saved: $error');
    }));
  }
}
