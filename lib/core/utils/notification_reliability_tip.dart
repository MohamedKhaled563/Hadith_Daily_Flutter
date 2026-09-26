import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_button.dart';
import '../widgets/botanical_sheet.dart';

/// A granted `POST_NOTIFICATIONS`/iOS authorization only means the OS *will*
/// show a notification if asked to — several device- and OS-level layers
/// beyond that can still keep the reader from ever seeing one:
///
///   - Xiaomi/Redmi/POCO (MIUI) and several other Android OEMs restrict
///     background work and scheduled alarms via their own Autostart/
///     battery-manager toggles, independent of Android's own permissions,
///     defaulting to off/restricted for a freshly installed app.
///   - iOS silences notifications under Focus/Do Not Disturb, or if the
///     reader denied the permission prompt outright (in which case nothing
///     is ever scheduled to begin with, but the reader may not remember
///     having denied it).
///
/// None of this is detectable or fixable purely from app code — there's no
/// public API for "is Autostart on," and no way to reach into Focus mode.
/// This shows a one-time, platform-appropriate tip pointing the reader at
/// the right settings screen instead of leaving reminders silently
/// unreliable with no explanation.
class NotificationReliabilityTip {
  static const _shownKey = 'notificationReliabilityTip.shown';
  static const _launchCountKey = 'notificationReliabilityTip.launches';

  /// How many times the app has to have been opened before the tip is allowed
  /// to appear on its own.
  ///
  /// It used to fire from a post-frame callback the first time HomeScreen
  /// mounted, and because both reminders default to on, that meant every new
  /// install's first sight of the app proper was a full-screen Android
  /// battery-settings explainer sitting on top of a hero they had not seen
  /// yet. The advice is genuinely useful — on several OEM builds reminders
  /// silently never fire — but it is meaningless to someone who has not yet
  /// read a single hadith, let alone waited for a reminder that failed to
  /// arrive.
  ///
  /// Three launches is roughly "they came back, and a morning reminder has
  /// plausibly been due by now".
  static const _minLaunchesBeforeAutoShow = 3;

  /// Counts an app launch, and returns whether the tip has earned the right
  /// to show itself unprompted. Call once per app start.
  static Future<bool> recordLaunchAndCheck() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) ?? false) return false;

    final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, count);
    return count >= _minLaunchesBeforeAutoShow;
  }

  /// Shows the tip once ever, and only when the reader actually has a
  /// reminder enabled — no point warning someone who isn't using the
  /// feature these restrictions would affect.
  ///
  /// [force] skips the launch-count wait, for the one place where the reader
  /// asked for this by their own action: switching a reminder on in settings.
  /// That is the moment the advice is about something they just did.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool anyReminderEnabled,
    bool force = false,
  }) async {
    if (!anyReminderEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) ?? false) return;
    if (!force &&
        (prefs.getInt(_launchCountKey) ?? 0) < _minLaunchesBeforeAutoShow) {
      return;
    }

    bool isXiaomiFamily = false;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        final manufacturer = info.manufacturer.toLowerCase();
        final brand = info.brand.toLowerCase();
        isXiaomiFamily = [manufacturer, brand].any(
          (s) =>
              s.contains('xiaomi') || s.contains('redmi') || s.contains('poco'),
        );
      } catch (_) {
        // Device info unavailable — still worth showing the generic
        // Android guidance below, just without the MIUI-specific note.
      }
    }

    // Mark as shown before actually showing it: if the reader dismisses the
    // app mid-dialog, this should still count as "shown" rather than
    // reappearing on every future launch.
    await prefs.setBool(_shownKey, true);
    if (!context.mounted) return;

    await showBotanicalSheet<void>(
      context: context,
      title: 'لضمان وصول التذكيرات',
      subtitle: Platform.isIOS
          ? 'خطوة أخيرة على جهاز آيفون'
          : 'خطوة أخيرة على جهازك',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_bodyText(isXiaomiFamily: isXiaomiFamily)),
          const SizedBox(height: 20),
          if (Platform.isIOS)
            AppButton(
              text: 'فتح إعدادات الإشعارات',
              onPressed: () => AppSettings.openAppSettings(
                type: AppSettingsType.notification,
              ),
            )
          else ...[
            AppButton(
              text: 'فتح إعدادات البطارية',
              onPressed: () => AppSettings.openAppSettings(
                type: AppSettingsType.batteryOptimization,
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'فتح إعدادات الإشعارات',
              isSecondary: true,
              onPressed: () => AppSettings.openAppSettings(
                type: AppSettingsType.notification,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // The sheet's own context, not the caller's: `context` here belongs
          // to whichever screen opened the tip (home, or the settings drawer),
          // so popping from it targets that screen's route — or, once the
          // drawer has closed, a deactivated element — and the tap did
          // nothing. Builder hands us a context inside the sheet's route.
          Builder(
            builder: (sheetContext) => AppButton(
              text: 'فهمت، شكراً',
              isSecondary: true,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ),
        ],
      ),
    );
  }

  static String _bodyText({required bool isXiaomiFamily}) {
    if (Platform.isIOS) {
      return 'تأكد من تفعيل الإشعارات لتطبيق «طيّب قلبك» من الإعدادات، '
          'وتحقق من أن وضع «التركيز» (Focus) أو «عدم الإزعاج» لا يكتم '
          'إشعاراته في الأوقات التي اخترتها للتذكير.';
    }

    final buffer = StringBuffer(
      'بعض أجهزة أندرويد تُقيّد عمل التطبيقات في الخلفية، مما قد يمنع '
      'وصول التذكيرات في وقتها. من إعدادات البطارية أدناه، اختر '
      '«بدون قيود» لهذا التطبيق، وتأكد أن إذن الإشعارات مفعّل.',
    );
    if (isXiaomiFamily) {
      buffer.write(
        '\n\nعلى وجه الخصوص، جهازك يعمل بنظام MIUI (شاومي/Redmi/POCO): '
        'افتح تطبيق «الأمان» (Security) ← الأذونات ← بدء التشغيل التلقائي '
        '(Autostart)، وفعّله لتطبيق «طيّب قلبك».',
      );
    }
    return buffer.toString();
  }
}
