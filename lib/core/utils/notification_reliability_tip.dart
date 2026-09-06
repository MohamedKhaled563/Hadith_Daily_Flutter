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

  /// Shows the tip once ever, and only when the reader actually has a
  /// reminder enabled — no point warning someone who isn't using the
  /// feature these restrictions would affect.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool anyReminderEnabled,
  }) async {
    if (!anyReminderEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) ?? false) return;

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
      title: 'لضمان وصول التذكيرات 🔔',
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
          AppButton(
            text: 'فهمت، شكراً',
            isSecondary: true,
            onPressed: () => Navigator.maybePop(context),
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
