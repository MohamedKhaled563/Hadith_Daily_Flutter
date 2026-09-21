import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_data_source.dart';

/// Outcome of a [NotificationScheduler.reschedule] call — lets callers (and
/// tests) tell "nothing to schedule" apart from "tried and failed", which
/// the previous fire-and-forget version couldn't distinguish.
@immutable
class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.scheduledCount,
    required this.usedExactAlarms,
    this.permissionGranted = true,
    this.superseded = false,
    this.error,
  });

  final int scheduledCount;
  final bool usedExactAlarms;

  /// Whether the OS will actually display any of what was just scheduled.
  /// Without this a denied POST_NOTIFICATIONS grant still reports a healthy
  /// `scheduledCount: 28, succeeded: true` — 28 notifications the OS drops
  /// on the floor, with nothing anywhere in the app able to tell.
  final bool permissionGranted;

  /// Whether a newer [NotificationScheduler.reschedule] started while this
  /// one was still in flight, so this run deliberately stopped rather than
  /// writing its now-stale settings over the newer ones.
  final bool superseded;

  final Object? error;

  bool get succeeded => error == null;
}

/// Schedules the morning/evening reminder notifications from
/// notificationMessages — entirely on-device, no server push (Spark plan,
/// see the roadmap). Two independent picks feed this:
///
///   - `settings/notificationMode` ('manual' | 'random', moderator/admin
///     controlled from the dashboard) decides HOW a day's message is
///     chosen.
///   - manual: every device computes the same index — `daysSinceEpoch %
///     pool.length` into the pool sorted by `order` — so everyone sees the
///     same message on the same calendar day with zero shared state.
///   - random: each device seeds its own `Random` once (persisted locally)
///     and mixes that seed with the date, so the same device always picks
///     the same message for a given future date (stable across repeated
///     rescheduling) while different devices likely diverge — acceptable
///     per-device personalisation that still needs no server component.
///
/// Notifications are scheduled `_daysAhead` days out at a time and
/// refreshed on every app start (and whenever the reminder settings
/// change), which is what keeps the rolling window populated without any
/// background execution beyond what the OS already does for a scheduled
/// local notification.
///
/// On Android 12+ an *inexact* alarm is not delivered at its requested time
/// — the OS batches it into a maintenance window that can be minutes to
/// hours later depending on the app's standby bucket. [reschedule] uses
/// `exactAllowWhileIdle` where the platform reports exact alarms are
/// available and `inexactAllowWhileIdle` otherwise.
///
/// The app does NOT declare SCHEDULE_EXACT_ALARM: Google Play restricts that
/// permission to alarm-clock/timer/calendar apps, so declaring it invites a
/// policy rejection. In practice that means the inexact path is the one
/// taken on Android 12+, which is what a reader on a device that declined
/// the grant was already getting.
class NotificationScheduler {
  NotificationScheduler._internal({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationDataSource? dataSource,
    DateTime Function()? clock,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _dataSource = dataSource ?? FirestoreNotificationDataSource(),
        _clock = clock ?? DateTime.now;

  static final NotificationScheduler instance = NotificationScheduler._internal();
  factory NotificationScheduler() => instance;

  /// Test-only seam: build an isolated instance with fakes instead of the
  /// real plugin/Firestore, so unit tests never touch a platform channel or
  /// a live project.
  ///
  /// [clock] pins what this instance believes "now" is. Without it every
  /// assertion about how many slots get scheduled depends on the wall clock
  /// at the moment the suite runs — "23:59 is still ahead unless it happens
  /// to execute at 23:59" — which is a test that quietly changes meaning
  /// overnight rather than one that fails honestly.
  @visibleForTesting
  factory NotificationScheduler.test({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationDataSource dataSource,
    DateTime Function()? clock,
  }) =>
      NotificationScheduler._internal(
        plugin: plugin,
        dataSource: dataSource,
        clock: clock,
      );

  static const _daysAhead = 14;
  static const _randomSeedKey = 'notificationScheduler.randomSeed';
  static const _cachedPoolKey = 'notificationScheduler.cachedPool';

  /// iOS/macOS init settings, named rather than inline so a test can assert
  /// on them — see the notification suite's "iOS initialization settings"
  /// group.
  ///
  /// All three request flags are off *on purpose*. They default to true,
  /// which makes `initialize()` itself fire the iOS system permission
  /// prompt — and since initialization is lazy (first [_ensureInitialized]),
  /// that lands on the very first frame of Home on a new install, before the
  /// reader has seen a single hadith. That is exactly the ambush
  /// NotificationReliabilityTip was already changed to avoid. Asking is
  /// [requestPermission]'s job, which every caller reaches deliberately.
  static const darwinInitSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestSoundPermission: false,
    requestBadgePermission: false,
  );

  /// Used only when the live Firestore fetch fails *and* there's no cached
  /// pool yet — a first-ever launch with no connectivity at all, which the
  /// SharedPreferences cache alone can't help with. Reminders are meant to
  /// feel fully on-device (see the class doc), so scheduling something
  /// generic beats reporting "check your internet" for a feature the reader
  /// never associated with the network in the first place.
  static const _bundledFallbackPool = <PoolMessage>[
    PoolMessage(
      id: 'bundled-1',
      text: 'خذ لحظة اليوم لتتذكر نعم الله عليك، فالشكر يزيد القلب طمأنينة.',
      order: 0,
    ),
    PoolMessage(
      id: 'bundled-2',
      text: 'ابتسامة، كلمة طيبة، أو دعوة صادقة — كلها صدقات في متناول يدك اليوم.',
      order: 1,
    ),
    PoolMessage(
      id: 'bundled-3',
      text: 'إن مع العسر يسراً — قف قليلاً وتنفّس، فالفرج قريب بإذن الله.',
      order: 2,
    ),
  ];

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationDataSource _dataSource;
  final DateTime Function() _clock;
  Future<void>? _initFuture;

  /// Fires whenever the reader taps a reminder while the app is running
  /// (foreground or backgrounded) — a plain tap signal, not the tapped
  /// notification's own text: the reminder pool (`notificationMessages`) is
  /// a separate, generic set of blurbs curated only to fill the notification
  /// body, not "today's message", so tapping must not reopen that text.
  /// Listeners instead re-fetch today's actual message (DailyTipService,
  /// same source the home screen's heart button uses). Incremented rather
  /// than a bool so two taps in a row (value already `true`) still notify.
  /// A cold start from a terminated state instead goes through
  /// [wasLaunchedByNotification], which SplashScreen checks once at launch.
  static final ValueNotifier<int> notificationTapped = ValueNotifier<int>(0);

  static void _onNotificationResponse(NotificationResponse response) {
    notificationTapped.value++;
  }

  // requestPermission() and reschedule() can both fire in close succession
  // (e.g. toggling a reminder switch right after app start) — without
  // memoising the in-flight Future, each call would race to invoke
  // _plugin.initialize() a second time on the same platform channel. If
  // init fails, drop the cached Future so the next call retries instead of
  // replaying the same failure forever.
  Future<void> _ensureInitialized() {
    final future = _initFuture ??= _doInitialize();
    future.catchError((_) => _initFuture = null);
    return future;
  }

  Future<void> _doInitialize() async {
    // Deliberately NOT using flutter_timezone + tz.setLocalLocation(named
    // IANA zone) here — see reschedule()'s doc comment for why: the
    // `timezone` package's bundled DST rules for a volatile zone
    // (Africa/Cairo, for the reader who reported this) can disagree with
    // the phone's own current offset, and flutter_local_notifications'
    // Android side re-derives the alarm time from a TZDateTime's *wall-clock
    // digits* — which inherit whatever offset the named zone's (possibly
    // wrong) rule assigns — rather than from its underlying instant. Only
    // tz_data.initializeTimeZones() is needed here; _deviceLocation() below
    // builds a location from the OS's own reported offset instead.
    tz_data.initializeTimeZones();

    // A dedicated white-silhouette drawable, not @mipmap/ic_launcher: that's
    // the full-color adaptive launcher icon, and Android's notification
    // shade either renders it as a blank white/gray block or forces its own
    // fallback glyph instead — see drawable/ic_stat_notify.xml.
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notify');
    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInitSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Whether the app was launched by tapping a reminder while fully
  /// terminated, checked once at startup since a cold start never fires
  /// [_onNotificationResponse]. Safe to call before [_ensureInitialized]:
  /// this reads native launch state directly, no plugin init required.
  Future<bool> wasLaunchedByNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+/iOS need an explicit runtime grant before any notification
  /// can show — call this once, e.g. the first time a reminder is enabled.
  /// Returns whether the notification permission was granted.
  ///
  /// This used to also call `requestExactAlarmsPermission()`. It no longer
  /// does: the app does not declare SCHEDULE_EXACT_ALARM (see the class doc
  /// and AndroidManifest.xml), so that request had nothing to grant, and
  /// asking for a permission the manifest doesn't declare is exactly the
  /// signal a Play policy review looks for.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  /// Re-lays the future `_daysAhead`-day window from today, honouring which
  /// of the two slots are enabled and at what time. Safe to call as often as
  /// needed — e.g. on every app start and every time a reminder setting
  /// changes.
  ///
  /// Deliberately never touches a slot that has already *fired* today (see
  /// [_syncOne]): an earlier version called `_plugin.cancelAll()` up front,
  /// which on Android also dismisses whatever is *currently showing* in the
  /// notification shade, not just pending alarms — so opening the app
  /// shortly after a reminder fired (e.g. to check whether it arrived) would
  /// silently wipe it out again via this same rolling reschedule. That is
  /// what made reminders look like they fired "randomly": they fired every
  /// time, but reopening the app right after often erased the evidence.
  ///
  /// Never throws: a Firestore/plugin failure is reported through the
  /// returned [NotificationScheduleResult] instead, so a transient offline
  /// error can't silently leave the user with zero scheduled reminders and
  /// no indication why.
  Future<NotificationScheduleResult> reschedule({
    required bool morningEnabled,
    required TimeOfDay morningTime,
    required bool eveningEnabled,
    required TimeOfDay eveningTime,
  }) async {
    final myGeneration = ++_rescheduleGeneration;
    bool superseded() => _rescheduleGeneration != myGeneration;
    const supersededResult = NotificationScheduleResult(
      scheduledCount: 0,
      usedExactAlarms: false,
      superseded: true,
    );

    try {
      await _ensureInitialized();

      var permissionGranted = true;
      if (morningEnabled || eveningEnabled) {
        // Reminders default to enabled, so the very first reschedule() call
        // (HomeScreen's initState, on the reader's first-ever app launch)
        // needs at least one reminder on — and that call never went through
        // requestPermission() at all, since only the settings-drawer toggle
        // used to call it. Without POST_NOTIFICATIONS actually granted, every
        // notification scheduled below is silently never shown by the OS, no
        // matter how successful this method itself reports. Requesting here
        // covers every caller instead of relying on each one to remember to.
        //
        // Guarded on its own: some OEM builds throw from the underlying
        // platform call itself (rather than just returning false) — that
        // must not abort scheduling outright and get blamed on connectivity
        // by the generic catch below, when it has nothing to do with it.
        try {
          permissionGranted = await requestPermission();
        } catch (error) {
          debugPrint('NotificationScheduler.requestPermission threw: $error');
        }
      }

      final pool = await _loadPool();
      final mode = await _dataSource.loadMode();
      final seed = await _deviceSeed();
      // A newer reschedule() overtook this one while it was waiting on the
      // permission prompt / Firestore / prefs above. Its settings are the
      // reader's actual latest choice, so stopping here is what keeps this
      // run's now-stale `morningEnabled`/`eveningEnabled` from being written
      // over them — see [NotificationScheduleResult.superseded].
      if (superseded()) return supersededResult;
      // Deliberately the device's own local clock, not
      // tz.TZDateTime.now(a named IANA zone): the `timezone` package's
      // bundled IANA data has repeatedly lagged Egypt's actual
      // (frequently-reversed) DST policy, which made Africa/Cairo resolve
      // up to an hour ahead of the phone's real clock — silently skipping
      // reminders that were still minutes away as "already past", and (once
      // that comparison was fixed here) still scheduling at the wrong
      // instant regardless, because flutter_local_notifications' Android
      // side re-derives the AlarmManager target from a TZDateTime's
      // wall-clock digits rather than its underlying instant, inheriting
      // whichever offset the zone's rule assigned to them. _syncOne works
      // around that by tagging the instant with _deviceLocation(now) — a
      // location built from this DateTime's own offset, with no DST rule to
      // disagree with the phone — instead of a named zone. None of this
      // depends on which real-world zone the device is in or whether its
      // clock is zone-synced or set manually: it only ever asks the OS what
      // time it is right now, which is also all the reader is looking at.
      final now = _clock();
      bool useExact;
      try {
        useExact = (await _android?.canScheduleExactNotifications()) ?? false;
      } catch (error) {
        // Some OEM builds throw here rather than just returning false/null
        // — falls back to inexact rather than failing the whole reschedule
        // over what's ultimately a "nice to have" scheduling precision.
        debugPrint('canScheduleExactNotifications threw: $error');
        useExact = false;
      }
      final scheduleMode = useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      // Which ids still have an alarm queued. A pending id has by definition
      // not fired yet, which is what lets [_syncOne] tell a stale alarm it
      // must clear apart from a delivered notification it must not touch.
      // Read once per run rather than per slot — it's a platform round trip.
      final pending = await _pendingIds();
      if (superseded()) return supersededResult;

      var scheduledCount = 0;
      for (var offset = 0; offset < _daysAhead; offset++) {
        if (superseded()) return supersededResult;

        final day = DateTime(now.year, now.month, now.day)
            .add(Duration(days: offset));
        // Two independent picks, one per slot: passing the *same* message to
        // both meant the evening reminder repeated the morning's text
        // verbatim, every single day.
        //
        // A pool this far down should never be empty (_loadPool falls back
        // to the bundled messages), but if it somehow were, indexing into it
        // would throw — and an exception here would abort the run *and* the
        // cancellation pass with it, which is the shape of the bug this
        // whole loop was moved out from behind. Cancel-only instead.
        final morning = pool.isEmpty
            ? null
            : pickMessageForDay(pool, day, mode, seed, slot: 0);
        final evening = pool.isEmpty
            ? null
            : pickMessageForDay(pool, day, mode, seed, slot: 1);

        final morningScheduled = await _syncOne(
          id: offset * 2,
          day: day,
          time: morningTime,
          enabled: morningEnabled && morning != null,
          title: 'رسالة الصباح',
          body: morning?.text ?? '',
          payload: morning?.id ?? '',
          now: now,
          scheduleMode: scheduleMode,
          pending: pending,
        );
        if (morningScheduled) scheduledCount++;

        final eveningScheduled = await _syncOne(
          id: offset * 2 + 1,
          day: day,
          time: eveningTime,
          enabled: eveningEnabled && evening != null,
          title: 'تأمل المساء',
          body: evening?.text ?? '',
          payload: evening?.id ?? '',
          now: now,
          scheduleMode: scheduleMode,
          pending: pending,
        );
        if (eveningScheduled) scheduledCount++;
      }

      return NotificationScheduleResult(
        scheduledCount: scheduledCount,
        usedExactAlarms: useExact,
        permissionGranted: permissionGranted,
      );
    } catch (error) {
      return NotificationScheduleResult(
        scheduledCount: 0,
        usedExactAlarms: false,
        error: error,
      );
    }
  }

  /// Monotonic run counter behind [NotificationScheduleResult.superseded].
  ///
  /// `reschedule()` is called from app start (fire-and-forget) and from every
  /// settings change, with nothing serialising them. Two runs interleaving
  /// their ~56 platform calls over the same ids means the *older* one's
  /// writes can land last — re-arming reminders the reader just switched
  /// off. Rather than serialise (which would make the newer, correct run
  /// wait on the stale one), the older run notices it has been overtaken and
  /// stops.
  int _rescheduleGeneration = 0;

  Future<Set<int>> _pendingIds() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return requests.map((r) => r.id).toSet();
    } catch (error) {
      // Treated as "nothing pending", which preserves the old, more
      // conservative behaviour: past slots are left alone.
      debugPrint('pendingNotificationRequests threw: $error');
      return const <int>{};
    }
  }

  /// Brings a single day/slot id in line with the current settings, and
  /// reports whether it ended up scheduled.
  ///
  /// A slot whose time has already passed today *and* has nothing queued
  /// under its id is left completely alone — no cancel, no reschedule —
  /// specifically so a reminder that already fired (and may still be sitting
  /// in the notification shade) survives the next [reschedule] call instead
  /// of being wiped by it. Every other slot is cancelled first (clearing any
  /// stale alarm/shown notification for that id) and then re-scheduled only
  /// if [enabled].
  ///
  /// The "nothing queued" half of that condition is load-bearing. Skipping
  /// on time alone left a real hole: move the morning reminder from 21:00 to
  /// 07:00 at 09:00, and the new time is in the past, so this returned
  /// before cancelling — leaving the old 21:00 alarm armed to fire tonight,
  /// at a time the reader had just changed away from. A *pending* id has not
  /// fired yet, so cancelling it cannot dismiss anything from the shade;
  /// a delivered one is no longer pending, so it still stays untouched.
  Future<bool> _syncOne({
    required int id,
    required DateTime day,
    required TimeOfDay time,
    required bool enabled,
    required String title,
    required String body,
    required String payload,
    required DateTime now,
    required AndroidScheduleMode scheduleMode,
    required Set<int> pending,
  }) async {
    final scheduled = resolveScheduledTime(day, time);
    if (isInPast(scheduled, now)) {
      if (!pending.contains(id)) return false;
      // Stale alarm from a previous, later time for this same slot.
      await _plugin.cancel(id);
      return false;
    }

    await _plugin.cancel(id);
    if (!enabled) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminders',
        'تذكيرات يومية',
        channelDescription: 'تذكير برسالة الصباح وتأمل المساء',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Tagged with a location built from the device's own live offset
    // (_deviceLocation), not a named IANA zone: flutter_local_notifications'
    // Android side re-derives the actual AlarmManager target from this
    // TZDateTime's *wall-clock digits*, re-interpreted through whatever
    // offset its location reports — so a named zone whose bundled DST rule
    // disagrees with the phone's real current offset (see reschedule()'s
    // doc) would still schedule at the wrong instant even though `scheduled`
    // itself is correct. A location with no DST rule to get wrong avoids
    // that regardless of the device's real-world zone, and works the same
    // way whether the OS clock is zone-synced or set manually.
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduled, _deviceLocation(now)),
      details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Kept only as a flutter_local_notifications-required field, not read
      // by the app: tapping a reminder no longer resolves back to this
      // notificationMessages doc — see NotificationScheduler.notificationTapped's
      // doc for why (that pool's text is a generic blurb, not "today's
      // message").
      payload: payload,
    );
    return true;
  }

  /// The reader thinks of reminders as a fully on-device feature (see the
  /// class doc) — a scheduled alarm does live entirely on the phone — but
  /// the message *content* is admin-curated in Firestore, so refreshing it
  /// still needs a network round trip every time this runs (app start,
  /// every reminder-setting change). Rather than let a momentary offline
  /// blip fail the whole reschedule with a "check your internet" error,
  /// this falls back to the last successfully fetched pool — cached
  /// locally — so a flaky connection degrades to "today's messages might
  /// be a little stale" instead of "reminders stopped working."
  Future<List<PoolMessage>> _loadPool() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final docs = await _dataSource.loadActiveMessages();
      final pool = buildPool(docs);
      if (pool.isNotEmpty) {
        await prefs.setString(
          _cachedPoolKey,
          jsonEncode(pool
              .map((m) => {'id': m.id, 'text': m.text, 'order': m.order})
              .toList()),
        );
        return pool;
      }
      // A successful fetch that came back empty (every message deactivated
      // from the dashboard, say) used to return the empty pool as-is, which
      // stopped reminders dead with `succeeded: true` and no way for anyone
      // to notice. Treated the same as a failed fetch instead: the reader's
      // reminders are theirs to switch off, not something an empty
      // collection should silently do for them.
      return _cachedOrBundledPool(prefs);
    } catch (_) {
      return _cachedOrBundledPool(prefs);
    }
  }

  /// The last successfully fetched pool, or the bundled one.
  ///
  /// The decode is guarded: a truncated or otherwise corrupt cache value
  /// used to throw straight out of the `catch` that called this, past the
  /// bundled fallback entirely, and surface to the reader as
  /// "تعذّر جدولة التذكيرات: FormatException" — the exact dead end the
  /// fallback exists to prevent.
  List<PoolMessage> _cachedOrBundledPool(SharedPreferences prefs) {
    final cached = prefs.getString(_cachedPoolKey);
    if (cached == null) return _bundledFallbackPool;
    try {
      final decoded = jsonDecode(cached) as List;
      final pool = decoded
          .map((e) => PoolMessage(
                id: (e as Map)['id'] as String? ?? '',
                text: e['text'] as String? ?? '',
                order: (e['order'] as num?)?.toInt() ?? 0,
              ))
          .where((m) => m.text.isNotEmpty)
          .toList();
      return pool.isEmpty ? _bundledFallbackPool : pool;
    } catch (error) {
      debugPrint('NotificationScheduler: dropping corrupt cached pool: $error');
      unawaited(prefs.remove(_cachedPoolKey));
      return _bundledFallbackPool;
    }
  }

  /// How many notifications are currently queued — used to confirm
  /// scheduling actually worked (tool/verify_rules.py-style manual check,
  /// no automated test harness for platform channels in this project).
  Future<int> pendingCount() async {
    await _ensureInitialized();
    return (await _plugin.pendingNotificationRequests()).length;
  }

  Future<int> _deviceSeed() async {
    final prefs = await SharedPreferences.getInstance();
    var seed = prefs.getInt(_randomSeedKey);
    if (seed == null) {
      seed = Random().nextInt(1 << 31);
      await prefs.setInt(_randomSeedKey, seed);
    }
    return seed;
  }
}

@immutable
class PoolMessage {
  const PoolMessage({required this.id, required this.text, required this.order});
  final String id;
  final String text;
  final int order;
}

/// Filters out inactive/blank-text docs and sorts by `order` — pulled out
/// of the Firestore call so it can be unit tested with plain maps.
List<PoolMessage> buildPool(List<Map<String, dynamic>> docs) {
  final pool = docs
      .map((data) => PoolMessage(
            id: data['id'] as String? ?? '',
            text: (data['text'] as String?)?.trim() ?? '',
            order: (data['order'] as num?)?.toInt() ?? 0,
          ))
      .where((m) => m.text.isNotEmpty)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return pool;
}

/// A [tz.Location] with a single, permanent [tz.TimeZone] fixed at [now]'s
/// own `timeZoneOffset` — i.e. whatever the OS/Dart says the device's UTC
/// offset actually is *right now*, with no DST rule (or IANA zone
/// identity) attached at all. Building this fresh from the live device
/// clock, instead of looking up a named zone via flutter_timezone +
/// tz.getLocation(), is what makes zonedSchedule's target immune to a
/// bundled-tzdata/real-world mismatch for any zone, on Android or iOS,
/// whether the OS clock is zone-synced or set manually — see
/// [NotificationScheduler.reschedule]'s doc for the bug this replaced.
///
/// Named as a `+HH:MM`/`-HH:MM` offset string rather than an arbitrary
/// label: flutter_local_notifications' Android side re-resolves this
/// [tz.Location]'s *name* through `java.time.ZoneId.of(...)` when it builds
/// the actual AlarmManager target, so an arbitrary name (tried first, and
/// it doesn't get simpler than "local") throws `Unknown time-zone ID` and
/// silently drops the whole reschedule — `ZoneId.of` does, however, accept
/// a fixed-offset string like `"+02:00"` directly, with no IANA lookup
/// involved, which is exactly the "no DST rule to get wrong" guarantee this
/// needs.
tz.Location _deviceLocation(DateTime now) {
  final offset = now.timeZoneOffset;
  final totalMinutes = offset.inMinutes;
  final sign = totalMinutes < 0 ? '-' : '+';
  final absMinutes = totalMinutes.abs();
  final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absMinutes % 60).toString().padLeft(2, '0');
  final name = '$sign$hours:$minutes';
  return tz.Location(
    name,
    const [],
    const [],
    [tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: name)],
  );
}

/// The exact instant a reminder for [day] at [time] should fire, as a plain
/// (device-local) [DateTime] — pulled out so tests can construct one
/// directly. Deliberately not a [tz.TZDateTime]: see [NotificationScheduler
/// .reschedule]'s doc for why local-time arithmetic here avoids the
/// `timezone` package's offset tables entirely.
DateTime resolveScheduledTime(DateTime day, TimeOfDay time) {
  return DateTime(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );
}

/// Whether [scheduled] has already passed [now] — a reminder in this state
/// is skipped rather than fired immediately/in the past. This is the exact
/// boundary check involved when a reminder set for "one minute from now"
/// does or doesn't go out.
bool isInPast(DateTime scheduled, DateTime now) => scheduled.isBefore(now);

/// Which pool message a given calendar day resolves to under 'manual' or
/// 'random' mode — pulled out of the class so it can be unit tested without
/// any platform/Firestore dependency.
/// [slot] distinguishes the day's two reminders (0 = morning, 1 = evening).
/// Both used to be handed the single message this returned, so the evening
/// reminder repeated the morning's text word for word every day. Slot 0 is
/// deliberately a no-op on both branches, so an existing day's morning pick
/// is exactly what it always was.
PoolMessage pickMessageForDay(
  List<PoolMessage> pool,
  DateTime day,
  String mode,
  int deviceSeed, {
  int slot = 0,
}) {
  final daysSinceEpoch = calendarDayNumber(day);
  if (mode == 'manual') {
    return pool[(daysSinceEpoch + slot) % pool.length];
  }
  // 0x9E3779B9 (the golden-ratio constant used by hash mixers) only to keep
  // the two slots' seeds far apart; `slot: 0` leaves the seed untouched.
  final random = Random(deviceSeed ^ daysSinceEpoch ^ (slot * 0x9E3779B9));
  return pool[random.nextInt(pool.length)];
}

/// [day]'s calendar date as a day number, read from its *calendar fields*
/// rather than its instant.
///
/// [NotificationScheduler.reschedule] builds each day as a local midnight,
/// whose `millisecondsSinceEpoch` lands on the previous UTC day anywhere
/// east of Greenwich. Dividing that raw value by a day — which this used to
/// do — therefore gave a reader in Cairo a different index than one in New
/// York for the very same date, quietly breaking the one guarantee 'manual'
/// mode exists to provide: that everybody sees the same message on the same
/// day. Re-anchoring the same y/m/d in UTC removes the offset entirely, and
/// makes the result independent of what time of day [day] happens to carry.
int calendarDayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
