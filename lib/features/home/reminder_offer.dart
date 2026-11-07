import 'package:flutter/material.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../data/services/notification_scheduler.dart';

/// Offers reminders to a new reader, in the app's own words, before anything
/// from the system appears.
///
/// The system dialog can be answered only once or twice, and after a refusal
/// the only way back is the phone's settings. So the app asks first: "no" here
/// costs nothing, and the real dialog is still available after the reader's
/// first reading. "Yes" goes straight on to it.
Future<void> offerReminders(
  BuildContext context, {
  @visibleForTesting Future<bool> Function()? claim,
  @visibleForTesting Future<void> Function()? accept,
}) async {
  final notifications = NotificationScheduler.instance;
  final offered = await (claim ?? notifications.claimReminderOffer)();
  if (!offered || !context.mounted) return;

  final accepted = await showBotanicalSheet<bool>(
    context: context,
    title: 'نذكّرك بحديث كل يوم؟',
    subtitle: 'رسالة في الصباح وأخرى في المساء، في الوقت الذي تختاره، '
        'ويمكنك إيقافها متى شئت.',
    child: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            text: 'نعم، ذكّرني',
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'ليس الآن',
            isSecondary: true,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    ),
  );

  if (accepted ?? false) await (accept ?? notifications.acceptReminderOffer)();
}
