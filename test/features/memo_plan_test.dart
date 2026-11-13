import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/memorization.dart';
import 'package:hadith_app/features/memorize/memo_list_screen.dart';

const _today = '2026-11-13';

void main() {
  group('MemoPlan', () {
    test('puts what is due first, and moves a review done today aside', () {
      const data = JourneyData(
        memo: {
          5: MemoProgress(box: 1, due: '2026-11-11'),
          6: MemoProgress(box: 0, due: _today),
          7: MemoProgress(box: 2, due: '2026-11-20'),
          9: MemoProgress(parts: 1),
          11: MemoProgress(box: 6),
          12: MemoProgress(box: 3, due: '2026-11-15'),
        },
        days: {
          _today: JourneyDay(reviewed: [7]),
        },
      );

      final plan = MemoPlan.of(data, _today);
      expect(plan.due, [5, 6], reason: 'the longest waiting first');
      expect(plan.reviewedToday, [7]);
      expect(plan.learning, [9]);
      expect(plan.held, [5, 6, 7, 11, 12]);
      expect(plan.next, 12, reason: 'the soonest review after today');
      expect(plan.doneToday, isFalse);
      expect(plan.isEmpty, isFalse);
    });

    test("lists today's first and the rest once, with no hadith twice", () {
      const data = JourneyData(
        memo: {
          5: MemoProgress(box: 1, due: '2026-11-11'),
          6: MemoProgress(box: 0, due: _today),
          7: MemoProgress(box: 2, due: '2026-11-20'),
          9: MemoProgress(parts: 1),
          11: MemoProgress(box: 6),
          12: MemoProgress(box: 3, due: '2026-11-15'),
        },
        days: {
          _today: JourneyDay(reviewed: [7]),
        },
      );

      final plan = MemoPlan.of(data, _today);
      expect(plan.todays, [5, 6, 7]);
      expect(plan.others, [11, 12]);
      final shown = [...plan.todays, ...plan.learning, ...plan.others];
      expect(shown.toSet(), hasLength(shown.length), reason: 'none twice');
      expect(
        shown.toSet(),
        {...plan.held, ...plan.learning},
        reason: 'and none left out',
      );
    });

    test('is done for the day once nothing due is left', () {
      const data = JourneyData(
        memo: {7: MemoProgress(box: 1, due: '2026-11-16')},
        days: {
          _today: JourneyDay(reviewed: [7]),
        },
      );

      final plan = MemoPlan.of(data, _today);
      expect(plan.due, isEmpty);
      expect(plan.doneToday, isTrue);
    });

    test('is empty with nothing memorized or started', () {
      final plan = MemoPlan.of(JourneyData.empty, _today);
      expect(plan.isEmpty, isTrue);
      expect(plan.doneToday, isFalse);
      expect(plan.next, isNull);
    });
  });

  test('counts hadiths the way Arabic says them', () {
    expect(hadithCount(1), 'حديث واحد');
    expect(hadithCount(2), 'حديثان');
    expect(hadithCount(5), '٥ أحاديث');
    expect(hadithCount(12), '١٢ حديثاً');
  });
}
