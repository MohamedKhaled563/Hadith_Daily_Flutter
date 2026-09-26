/// The admin-curated calendar for the morning/evening reminders, stored at
/// `settings/notificationSchedule` and edited from the dashboard's
/// «رسائل التنبيه» tab. Shape:
///
/// ```
/// days: {
///   '2026-09-27': {
///     'morning': {'messageId': 'abc', 'text': '…', 'setAt': Timestamp},
///     'evening': {'messageId': 'def', 'text': '…', 'setAt': Timestamp},
///   },
/// }
/// ```
///
/// Either slot may be missing — an unpinned slot is filled at random on each
/// device (see pickMessageForDay), exactly like an unpinned slot on the
/// daily-message calendar. A past date simply stops being looked up, so
/// nothing ever needs reverting.
library;

/// The two reminder slots, in the order NotificationScheduler lays them out
/// (slot 0 = morning, slot 1 = evening).
const kNotificationSlots = ['morning', 'evening'];

const kNotificationSlotLabels = {
  'morning': 'رسالة الصباح',
  'evening': 'تأمل المساء',
};

/// yyyy-MM-dd of [d]'s *calendar fields* — the same key format as
/// `settings/dailyMessageSchedule`, so both calendars read alike.
String notificationDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The raw `days` map reduced to dateKey → slot → messageId, dropping
/// anything malformed rather than throwing — a hand-edited or half-written
/// doc must never stop reminders from being scheduled.
Map<String, Map<String, String>> parseNotificationSchedule(Object? days) {
  final result = <String, Map<String, String>>{};
  if (days is! Map) return result;
  for (final day in days.entries) {
    final key = day.key;
    final value = day.value;
    if (key is! String || value is! Map) continue;
    final slots = <String, String>{};
    for (final slot in kNotificationSlots) {
      final pin = value[slot];
      final id = pin is Map ? pin['messageId'] : null;
      if (id is String && id.isNotEmpty) slots[slot] = id;
    }
    if (slots.isNotEmpty) result[key] = slots;
  }
  return result;
}
