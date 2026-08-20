import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../services/daily_hadith_service.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _baseId = 1000;
  static const _daysToSchedule = 30;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return androidGranted ?? iosGranted ?? false;
  }

  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (kIsWeb) return;
    await initialize();
    await cancelDaily();

    final today = DateTime.now();
    for (var offset = 0; offset < _daysToSchedule; offset++) {
      final date = DateTime(today.year, today.month, today.day).add(Duration(days: offset));
      var scheduled = tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) continue;

      final hadith = await DailyHadithService.getForDate(date);
      await _plugin.zonedSchedule(
        id: _baseId + offset,
        title: 'حديثك اليوم 🌿',
        body: _notificationBody(hadith.text),
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_hadith',
            'حديثك اليوم',
            channelDescription: 'تذكير يومي بقراءة حديث اليوم',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelDaily() async {
    if (kIsWeb) return;
    await initialize();
    for (var i = 0; i < _daysToSchedule; i++) {
      await _plugin.cancel(id: _baseId + i);
    }
  }

  String _notificationBody(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 110) return normalized;
    return '${normalized.substring(0, 107)}...';
  }
}
