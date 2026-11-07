import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/data/services/daily_tip_service.dart';

/// Only the pure, static half of DailyTipService is covered here — the rest
/// reaches straight for FirebaseFirestore.instance and has no seam to fake
/// it through (unlike NotificationScheduler.test).
void main() {
  group('DailyTipService.repairDay', () {
    DailyTip tip(String id, String text) => DailyTip(
          id: id,
          sourceCollection: 'dailyMessages',
          text: text,
          hadithNumber: 1,
          category: 'رسالة اليوم',
        );

    List<String> ids(List<DailyTip> tips) => [for (final t in tips) t.id];

    test('a day whose messages all still exist is left as it is', () {
      final day = [tip('a', 'أولى'), tip('b', 'ثانية')];

      final repaired =
          DailyTipService.repairDay(day, [...day, tip('c', 'ثالثة')]);

      expect(ids(repaired.day), ['a', 'b']);
      expect(repaired.drawn, isEmpty);
    });

    test('a message uploaded again keeps its place under its new id', () {
      final day = [tip('a', 'أولى'), tip('old', 'رسالة  أعيد رفعها ')];
      final pool = [tip('a', 'أولى'), tip('new', 'رسالة أعيد رفعها')];

      final repaired = DailyTipService.repairDay(day, pool);

      expect(ids(repaired.day), ['a', 'new']);
      expect(repaired.drawn, isEmpty, reason: 'it was already shown today');
    });

    test('a deleted message is replaced in its place by one not in the day',
        () {
      final day = [tip('gone', 'حُذفت'), tip('b', 'ثانية')];
      final pool = [tip('b', 'ثانية'), tip('c', 'ثالثة')];

      final repaired = DailyTipService.repairDay(day, pool);

      expect(ids(repaired.day), ['c', 'b']);
      expect(ids(repaired.drawn), ['c']);
    });

    test('two missing messages never get the same replacement', () {
      final day = [tip('x', 'حُذفت'), tip('y', 'حُذفت أيضاً')];
      final pool = [tip('c', 'ثالثة'), tip('d', 'رابعة')];

      final repaired = DailyTipService.repairDay(day, pool);

      expect(ids(repaired.day).toSet(), {'c', 'd'});
    });

    test('with nothing left to draw, a missing message is dropped', () {
      final day = [tip('gone', 'حُذفت'), tip('b', 'ثانية')];

      final repaired = DailyTipService.repairDay(day, [tip('b', 'ثانية')]);

      expect(ids(repaired.day), ['b']);
    });

    test('an edited message takes its new text', () {
      final day = [tip('a', 'قبل التعديل')];

      final repaired =
          DailyTipService.repairDay(day, [tip('a', 'بعد التعديل')]);

      expect(repaired.day.single.text, 'بعد التعديل');
    });
  });

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

  group('DailyTipService.localPoolIsTrusted', () {
    final fresh = const Duration(days: 1).inMilliseconds;
    final maxAge = DailyTipService.poolMaxAge.inMilliseconds;

    test('a device that has never synced does not trust its cache', () {
      // Regression: an unreadable version used to trust the local copy
      // outright. The cache is filled by every other read in the app, so a
      // device that had never fetched the pool drew its whole day from
      // whatever happened to be there — with no daily messages among it.
      expect(
        DailyTipService.localPoolIsTrusted(
          liveVersion: null,
          syncedVersion: null,
          ageMillis: fresh,
        ),
        isFalse,
      );
      expect(
        DailyTipService.localPoolIsTrusted(
          liveVersion: 4,
          syncedVersion: null,
          ageMillis: fresh,
        ),
        isFalse,
      );
    });

    test('an unreadable version settles for a pool once synced', () {
      expect(
        DailyTipService.localPoolIsTrusted(
          liveVersion: null,
          syncedVersion: 4,
          ageMillis: maxAge * 2,
        ),
        isTrue,
      );
    });

    test('a matching version within the max age is trusted', () {
      expect(
        DailyTipService.localPoolIsTrusted(
          liveVersion: 4,
          syncedVersion: 4,
          ageMillis: fresh,
        ),
        isTrue,
      );
    });

    test('a version that moved is not trusted', () {
      expect(
        DailyTipService.localPoolIsTrusted(
          liveVersion: 5,
          syncedVersion: 4,
          ageMillis: fresh,
        ),
        isFalse,
      );
    });

    test('a pool at the max age, or stamped in the future, is not trusted', () {
      for (final age in [maxAge, -1]) {
        expect(
          DailyTipService.localPoolIsTrusted(
            liveVersion: 4,
            syncedVersion: 4,
            ageMillis: age,
          ),
          isFalse,
          reason: 'age $age',
        );
      }
    });
  });
}
