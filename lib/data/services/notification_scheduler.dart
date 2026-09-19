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
    this.error,
  });

  final int scheduledCount;
  final bool usedExactAlarms;
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
/// On Android 12+ an *inexact* alarm (the previous, only mode this class
/// used) is not delivered at its requested time — the OS batches it into a
/// maintenance window that can be minutes to hours later depending on the
/// app's standby bucket, which is why a reminder set "one minute from now"
/// can appear to never fire. [reschedule] now asks for the exact-alarm
/// permission and uses `exactAllowWhileIdle` whenever it has been granted,
/// falling back to the inexact mode only when it hasn't.
class NotificationScheduler {
  NotificationScheduler._internal({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationDataSource? dataSource,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _dataSource = dataSource ?? FirestoreNotificationDataSource();

  static final NotificationScheduler instance = NotificationScheduler._internal();
  factory NotificationScheduler() => instance;

  /// Test-only seam: build an isolated instance with fakes instead of the
  /// real plugin/Firestore, so unit tests never touch a platform channel or
  /// a live project.
  @visibleForTesting
  factory NotificationScheduler.test({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationDataSource dataSource,
  }) =>
      NotificationScheduler._internal(plugin: plugin, dataSource: dataSource);

  static const _daysAhead = 14;
  static const _randomSeedKey = 'notificationScheduler.randomSeed';
  static const _cachedPoolKey = 'notificationScheduler.cachedPool';

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
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
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
  /// can show, and Android 12+ separately gates *exact* alarms behind their
  /// own grant — call this once, e.g. the first time a reminder is enabled.
  /// Returns whether the notification permission itself was granted; exact
  /// alarms are best-effort (checked again in [reschedule]) since some
  /// OEMs/OS versions don't support requesting them at all.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return granted;
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
  /// Deliberately never touches a slot whose time has already passed today
  /// (see [_syncOne]): an earlier version called `_plugin.cancelAll()`
  /// up front, which on Android also dismisses whatever is *currently
  /// showing* in the notification shade, not just pending alarms — so
  /// opening the app shortly after a reminder fired (e.g. to check whether
  /// it arrived) would silently wipe it out again via this same rolling
  /// reschedule. That is what made reminders look like they fired
  /// "randomly": they fired every time, but reopening the app right after
  /// often erased the evidence.
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
    try {
      await _ensureInitialized();

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
          await requestPermission();
        } catch (error) {
          debugPrint('NotificationScheduler.requestPermission threw: $error');
        }
      }

      final pool = await _loadPool();
      if (pool.isEmpty) {
        return const NotificationScheduleResult(
          scheduledCount: 0,
          usedExactAlarms: false,
        );
      }

      final mode = await _dataSource.loadMode();
      final seed = await _deviceSeed();
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
      final now = DateTime.now();
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

      var scheduledCount = 0;
      for (var offset = 0; offset < _daysAhead; offset++) {
        final day = DateTime(now.year, now.month, now.day)
            .add(Duration(days: offset));
        final message = pickMessageForDay(pool, day, mode, seed);

        final morningScheduled = await _syncOne(
          id: offset * 2,
          day: day,
          time: morningTime,
          enabled: morningEnabled,
          title: 'رسالة الصباح 🌅',
          body: message.text,
          payload: message.id,
          now: now,
          scheduleMode: scheduleMode,
        );
        if (morningScheduled) scheduledCount++;

        final eveningScheduled = await _syncOne(
          id: offset * 2 + 1,
          day: day,
          time: eveningTime,
          enabled: eveningEnabled,
          title: 'تأمل المساء 🌙',
          body: message.text,
          payload: message.id,
          now: now,
          scheduleMode: scheduleMode,
        );
        if (eveningScheduled) scheduledCount++;
      }

      return NotificationScheduleResult(
        scheduledCount: scheduledCount,
        usedExactAlarms: useExact,
      );
    } catch (error) {
      return NotificationScheduleResult(
        scheduledCount: 0,
        usedExactAlarms: false,
        error: error,
      );
    }
  }

  /// Brings a single day/slot id in line with the current settings, and
  /// reports whether it ended up scheduled.
  ///
  /// A slot whose time has already passed today is left completely alone —
  /// no cancel, no reschedule — specifically so a reminder that already
  /// fired (and may still be sitting in the notification shade) survives
  /// the next [reschedule] call instead of being wiped by it. Every other
  /// slot is cancelled first (clearing any stale alarm/shown notification
  /// for that id) and then re-scheduled only if [enabled].
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
  }) async {
    final scheduled = resolveScheduledTime(day, time);
    if (isInPast(scheduled, now)) return false;

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
      }
      return pool;
    } catch (_) {
      final cached = prefs.getString(_cachedPoolKey);
      if (cached == null) return _bundledFallbackPool;
      final decoded = jsonDecode(cached) as List;
      return decoded
          .map((e) => PoolMessage(
                id: (e as Map)['id'] as String? ?? '',
                text: e['text'] as String? ?? '',
                order: (e['order'] as num?)?.toInt() ?? 0,
              ))
          .toList();
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
PoolMessage pickMessageForDay(
  List<PoolMessage> pool,
  DateTime day,
  String mode,
  int deviceSeed,
) {
  final daysSinceEpoch = day.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
  if (mode == 'manual') {
    return pool[daysSinceEpoch % pool.length];
  }
  final random = Random(deviceSeed ^ daysSinceEpoch);
  return pool[random.nextInt(pool.length)];
}
