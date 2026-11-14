import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/services/notification_planner.dart';

/// Every state in the plan's table of what each slot says. Pure logic, so it
/// runs the same on the host and on a device.
void notificationPlannerSuite() {
  const today = '2026-11-07';
  final morning = DateTime(2026, 11, 7, 8, 30);
  final evening = DateTime(2026, 11, 7, 20);

  /// A reader who read on the days [daysAgo] before today.
  JourneyData readOn(Iterable<int> daysAgo, {Set<int> complete = const {}}) {
    return JourneyData(
      startedOn: '2026-01-01',
      days: {
        for (final ago in daysAgo)
          dayKeyPlus(today, -ago): const JourneyDay(messages: ['m']),
      },
      hadith: {
        for (final number in complete)
          number: const HadithProgress(fullOn: '2026-10-01'),
      },
    );
  }

  ReminderFacts facts(JourneyData data, {bool signedIn = true}) =>
      ReminderFacts(
        signedIn: signedIn,
        data: data,
        hadithTitle: (number) => number == 16 ? 'لا تغضب' : 'الحديث $number',
        hadithMinutes: (_) => 2,
      );

  PlannedReminder? plan(
    JourneyData data,
    ReminderSlot slot, {
    bool signedIn = true,
    DateTime? at,
  }) =>
      planReminder(
        facts(data, signedIn: signedIn),
        at: at ?? (slot == ReminderSlot.morning ? morning : evening),
        slot: slot,
      );

  group('planReminder', () {
    test('a guest gets the pool, whatever they have read', () {
      final data = readOn([1, 2, 3]);

      expect(plan(data, ReminderSlot.morning, signedIn: false), isNull);
      expect(plan(data, ReminderSlot.evening, signedIn: false), isNull);
    });

    test('a reader who has not started gets the pool', () {
      expect(plan(JourneyData.empty, ReminderSlot.morning), isNull);
      expect(plan(JourneyData.empty, ReminderSlot.evening), isNull);
    });

    test('a reader who already read today hears nothing about reading', () {
      final data = readOn([0, 1, 2, 3, 4]);

      expect(plan(data, ReminderSlot.morning), isNull);
      expect(plan(data, ReminderSlot.evening), isNull);
    });

    group('on an ordinary day', () {
      test('the morning names the next hadith and how long it takes', () {
        final data = readOn([1], complete: {for (var n = 1; n <= 15; n++) n});

        final reminder = plan(data, ReminderSlot.morning)!;

        expect(reminder.title, 'حديث اليوم');
        expect(reminder.body, '«لا تغضب»، دقيقتان تقريباً.');
        expect(reminder.payload, 'hadith:16');
      });

      test('the morning falls back to the pool once all 42 are read', () {
        final data = readOn([1], complete: {for (var n = 1; n <= 42; n++) n});

        expect(plan(data, ReminderSlot.morning), isNull);
      });

      test('the evening mentions a streak of three', () {
        final reminder = plan(readOn([1, 2, 3]), ReminderSlot.evening)!;

        expect(reminder.title, 'لم نقرأ اليوم بعد');
        expect(reminder.body, '٣ أيام متتالية. حديث قصير قبل النوم؟');
        expect(reminder.payload, 'hadith:1');
      });

      test('the evening counts in the form Arabic asks for', () {
        final reminder = plan(
          readOn([for (var ago = 1; ago <= 12; ago++) ago]),
          ReminderSlot.evening,
        )!;

        expect(reminder.body, startsWith('١٢ يوماً متتالية.'));
      });

      test('a streak of two is not yet worth a nudge', () {
        expect(plan(readOn([1, 2]), ReminderSlot.evening), isNull);
      });
    });

    group('after a short absence', () {
      test('one missed day covered by a grace day says the streak is safe', () {
        // Seven days in a row earn a grace day, and yesterday used it.
        final reminder = plan(
          readOn([for (var ago = 2; ago <= 9; ago++) ago]),
          ReminderSlot.morning,
        )!;

        expect(reminder.title, 'لا بأس');
        expect(reminder.body, 'فاتك أمس، واستمراريتك كما هي. نكمل اليوم؟');
      });

      test('one missed day with no grace day keeps their place', () {
        final reminder = plan(readOn([2]), ReminderSlot.morning)!;

        expect(reminder.title, 'مكانك محفوظ');
        expect(reminder.body, 'توقفنا عند «الحديث 1». نكمل حين يناسبك.');
        expect(reminder.payload, 'hadith:1');
      });

      test('only days 1, 3 and 7 say anything', () {
        final Map<int, String?> titles = {
          for (var missed = 1; missed <= 8; missed++)
            missed: plan(readOn([missed + 1]), ReminderSlot.morning)?.title,
        };

        expect(titles, {
          1: 'مكانك محفوظ',
          2: null,
          3: 'مكانك محفوظ',
          4: null,
          5: null,
          6: null,
          7: 'مكانك محفوظ',
          8: null,
        });
      });

      test('the evening stays out of it', () {
        expect(plan(readOn([2]), ReminderSlot.evening), isNull);
        expect(plan(readOn([4]), ReminderSlot.evening), isNull);
      });
    });

    test('after a week away nothing mentions their reading', () {
      for (final away in [9, 10, 30, 200]) {
        final data = readOn([away]);

        expect(plan(data, ReminderSlot.morning), isNull, reason: '$away');
        expect(plan(data, ReminderSlot.evening), isNull, reason: '$away');
      }
    });

    group('for a reader who does not come back', () {
      // Read today, then nothing. Each day ahead is planned from today's facts.
      final data = readOn([0, 1, 2]);
      DateTime daysAhead(int days, int hour) =>
          DateTime(2026, 11, 7 + days, hour);

      test('tomorrow is an ordinary day', () {
        expect(
          plan(data, ReminderSlot.morning, at: daysAhead(1, 8))?.title,
          'حديث اليوم',
        );
        expect(
          plan(data, ReminderSlot.evening, at: daysAhead(1, 20))?.body,
          '٣ أيام متتالية. حديث قصير قبل النوم؟',
        );
      });

      test('the day after keeps their place', () {
        expect(
          plan(data, ReminderSlot.morning, at: daysAhead(2, 8))?.title,
          'مكانك محفوظ',
        );
      });

      test('after a week the window goes quiet', () {
        expect(plan(data, ReminderSlot.morning, at: daysAhead(9, 8)), isNull);
      });
    });

    test('a reminder after midnight belongs to the evening still running', () {
      // 01:00 on the 8th is still the 7th's reading day, already read.
      final late = DateTime(2026, 11, 8, 1);

      expect(plan(readOn([0, 1, 2]), ReminderSlot.evening, at: late), isNull);
    });

    test('a hadith with no title falls back to the pool', () {
      final reminder = planReminder(
        ReminderFacts(
          signedIn: true,
          data: readOn([1]),
          hadithTitle: (_) => null,
          hadithMinutes: (_) => 2,
        ),
        at: morning,
        slot: ReminderSlot.morning,
      );

      expect(reminder, isNull);
    });
  });

  group('payloads', () {
    test('round-trip a hadith number', () {
      expect(hadithOfPayload(hadithPayload(16)), 16);
    });

    test('leave anything else alone', () {
      expect(hadithOfPayload(null), isNull);
      expect(hadithOfPayload(''), isNull);
      expect(hadithOfPayload('Xk29fjQ'), isNull);
      expect(hadithOfPayload('hadith:'), isNull);
      expect(hadithOfPayload('hadith:abc'), isNull);
    });
  });

  group('reminderPlanKey', () {
    String key(JourneyData data, {bool signedIn = true, String day = today}) =>
        reminderPlanKey(facts(data, signedIn: signedIn), day);

    test('moves when today gets its first reading', () {
      expect(key(readOn([0, 1])), isNot(key(readOn([1]))));
    });

    test('moves when a hadith is finished', () {
      expect(
        key(readOn([1], complete: {1})),
        isNot(key(readOn([1]))),
      );
    });

    test('stays put for what no reminder mentions', () {
      final quiet = readOn([0, 1]);
      final wrote = quiet.apply(const JourneyEvent(dayKey: today, wrote: 1));
      final timed = quiet.apply(const JourneyEvent(dayKey: today, seconds: 90));

      expect(key(wrote), key(quiet));
      expect(key(timed), key(quiet));
    });

    test('is the same for every guest', () {
      expect(
          key(readOn([1]), signedIn: false), key(readOn([3]), signedIn: false));
    });
  });
}
