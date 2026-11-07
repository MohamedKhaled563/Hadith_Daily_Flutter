import '../../core/theme/app_state_controller.dart';
import '../journey/journey_engine.dart';
import '../journey/journey_repository.dart';
import '../journey/reading_tracker.dart';
import '../repositories/hadith_repository.dart';
import 'notification_planner.dart';
import 'notification_scheduler.dart';

/// Connects the pure planner to the app's live data.
class JourneyReminders {
  const JourneyReminders._();

  static ReminderFacts _facts() {
    final journey = JourneyRepository();
    final hadiths = HadithRepository();
    return ReminderFacts(
      signedIn: !journey.isGuest,
      data: journey.data,
      hadithTitle: (number) => hadiths.getByNumber(number)?.title,
      hadithMinutes: (number) {
        final hadith = hadiths.getByNumber(number);
        return hadith == null ? 1 : ReadingRule.minutesFor(hadith);
      },
    );
  }

  /// [NotificationScheduler.planner] for the running app.
  static PlannedReminder? plan(DateTime at, ReminderSlot slot) =>
      planReminder(_facts(), at: at, slot: slot);

  /// What the schedule was last built from: the reader, what they have read,
  /// and their reminder settings.
  static String planKey() {
    final state = AppStateController();
    return [
      JourneyRepository().uid ?? '-',
      reminderPlanKey(_facts(), journeyDayKey(DateTime.now())),
      state.reminderPrefs.toJson().values.join(','),
    ].join('#');
  }

  /// The first time a reader has actually read something is a fair moment to
  /// ask for notifications: they now know what the app is for. A reader who
  /// switched both reminders off has already answered.
  static Future<void> askAfterReading() async {
    final state = AppStateController();
    if (!state.morningReminderEnabled && !state.eveningReminderEnabled) return;
    await NotificationScheduler.instance.askOnce();
  }
}
