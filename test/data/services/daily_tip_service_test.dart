import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/data/services/daily_tip_service.dart';

/// Only the pure, static half of DailyTipService is covered here — the rest
/// reaches straight for FirebaseFirestore.instance and has no seam to fake
/// it through (unlike NotificationScheduler.test).
void main() {
  group('DailyTipService.normaliseScheduledDay', () {
    test('a date with nothing pinned yields a growable list', () {
      final entries = DailyTipService.normaliseScheduledDay(null);

      expect(entries, isEmpty);
      // Regression: this used to return `const []`, so pinning the FIRST
      // message of a date threw "Cannot add to an unmodifiable list" —
      // DailyMessageSchedulePage adds to this list in place. On Flutter web
      // that surfaced only as "Dart exception thrown from converted Future",
      // which is why it went unnoticed until the dashboard was deployed.
      expect(() => entries.add({'messageId': 'a'}), returnsNormally);
      expect(entries, hasLength(1));
    });

    test('a legacy single-object pin reads as a one-item list', () {
      final entries = DailyTipService.normaliseScheduledDay({
        'messageId': 'abc',
        'text': 'رسالة',
      });

      expect(entries, hasLength(1));
      expect(entries.single['messageId'], 'abc');
      expect(() => entries.add({'messageId': 'b'}), returnsNormally);
    });

    test('a list of pins keeps its order and stays growable', () {
      final entries = DailyTipService.normaliseScheduledDay([
        {'messageId': 'first'},
        {'messageId': 'second'},
      ]);

      expect(entries.map((e) => e['messageId']), ['first', 'second']);
      expect(() => entries.removeWhere((e) => e['messageId'] == 'first'),
          returnsNormally);
      expect(entries.single['messageId'], 'second');
    });

    test('non-map junk in the list is dropped rather than crashing', () {
      final entries = DailyTipService.normaliseScheduledDay([
        {'messageId': 'good'},
        'not a pin',
        42,
        null,
      ]);

      expect(entries, hasLength(1));
      expect(entries.single['messageId'], 'good');
    });

    test('an unexpected scalar yields an empty growable list', () {
      final entries = DailyTipService.normaliseScheduledDay('nonsense');

      expect(entries, isEmpty);
      expect(() => entries.add({'messageId': 'a'}), returnsNormally);
    });
  });
}
