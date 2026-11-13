import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/memorization.dart';
import 'package:hadith_app/data/journey/tree_memory.dart';
import 'package:hadith_app/features/journey/journey_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = '2026-11-13';

JourneyData _journey({Set<int> read = const {}, Set<int> held = const {}}) =>
    JourneyData(
      hadith: {
        for (final number in read)
          number: const HadithProgress(fullOn: '2026-11-12'),
      },
      memo: {for (final number in held) number: const MemoProgress(box: 1)},
    );

Future<void> _pumpTree(
  WidgetTester tester,
  JourneyData data, {
  String? account,
  bool ready = true,
  bool still = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: JourneyTree(
                data: data,
                account: account,
                today: _today,
                ready: ready,
                titleOf: (_) => '',
                onLeafTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // TreeMemory reads the phone's copy before anything is held back.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

JourneyTreePainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<JourneyTreePainter>()
    .single;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TreeMemory', () {
    test('keeps each account apart, and a guest apart from both', () async {
      await TreeMemory.save(
        'a',
        const TreeSeen(leaves: {1, 2}, fruit: {1}, day: _today),
      );

      final a = await TreeMemory.load('a');
      expect(a.leaves, {1, 2});
      expect(a.fruit, {1});
      expect(a.day, _today);
      expect((await TreeMemory.load('b')).leaves, isEmpty);
      expect((await TreeMemory.load(null)).leaves, isEmpty);
    });
  });

  group('the leaves', () {
    test('show one of three looks: not read, read, memorized', () {
      final looks = leafLooks(_journey(read: {1, 2}, held: {2}));
      expect(looks[1], LeafLook.complete);
      expect(looks[2], LeafLook.memorized);
      expect(looks[3], LeafLook.empty);
      expect(looks, hasLength(42));
    });

    test('sit on the painting, none on top of another', () {
      final leaves = TreeLayout.instance.leaves;
      expect([for (final leaf in leaves) leaf.number], [
        for (var i = 1; i <= 42; i++) i,
      ]);
      for (final leaf in leaves) {
        expect(leaf.centre.dx, inInclusiveRange(0, TreeLayout.width));
        expect(leaf.centre.dy, inInclusiveRange(0, TreeLayout.ground));
        for (final other in leaves) {
          if (other == leaf) continue;
          expect(
            (leaf.centre - other.centre).distance,
            greaterThan(TreeLayout.leafLength * .8),
            reason: 'leaves ${leaf.number} and ${other.number}',
          );
        }
      }
    });

    test('are numbered in a sweep from the lower left to the lower right',
        () {
      final leaves = TreeLayout.instance.leaves;
      expect(leaves.first.centre.dx, lessThan(TreeLayout.width / 2));
      expect(leaves.last.centre.dx, greaterThan(TreeLayout.width / 2));
      expect(leaves[20].centre.dy, lessThan(TreeLayout.height / 3),
          reason: 'the middle of the count is at the top');
    });
  });

  group('the living tree', () {
    testWidgets('opens only the leaf the reader has not seen yet',
        (tester) async {
      await TreeMemory.save(
        null,
        const TreeSeen(leaves: {1}, day: _today),
      );
      await _pumpTree(tester, _journey(read: {1, 2}));

      final motion = _painter(tester).motion!;
      expect(motion.grownOf(1), 1, reason: 'seen before, already open');
      expect(motion.grownOf(2), 0, reason: 'held as a bud until it grows');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      expect(motion.grownOf(2), 1);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect((await TreeMemory.load(null)).leaves, {1, 2});
    });

    testWidgets('greets the reader once a day by opening every leaf',
        (tester) async {
      await TreeMemory.save(
        null,
        const TreeSeen(leaves: {1, 2}, day: '2026-11-12'),
      );
      await _pumpTree(tester, _journey(read: {1, 2}));

      final motion = _painter(tester).motion!;
      expect(motion.grownOf(1), 0);
      expect(motion.grownOf(2), 0);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      expect(motion.grownOf(1), 1);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect((await TreeMemory.load(null)).day, _today);
    });

    testWidgets('grows a fruit for a hadith newly memorized', (tester) async {
      await TreeMemory.save(
        'reader',
        const TreeSeen(leaves: {3}, day: _today),
      );
      await _pumpTree(
        tester,
        _journey(read: {3}, held: {3}),
        account: 'reader',
      );

      final motion = _painter(tester).motion!;
      expect(motion.grownOf(3), 1);
      expect(motion.fruitOf(3), 0);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      expect(motion.fruitOf(3), 1);
    });

    testWidgets('grows nothing before the journey has loaded', (tester) async {
      await _pumpTree(tester, _journey(read: {1, 2}), ready: false);

      final motion = _painter(tester).motion!;
      expect(motion.grownOf(1), 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect((await TreeMemory.load(null)).leaves, isEmpty);
    });

    testWidgets('stands still with reduced motion, and still remembers',
        (tester) async {
      await _pumpTree(tester, _journey(read: {1, 2}), still: true);

      expect(_painter(tester).motion, isNull);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      final seen = await TreeMemory.load(null);
      expect(seen.leaves, {1, 2});
      expect(seen.day, _today);
    });

    testWidgets('a tapped leaf rustles and opens its hadith', (tester) async {
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: TreeLayout.width,
                child: JourneyTree(
                  data: _journey(),
                  titleOf: (_) => '',
                  onLeafTap: (number) => opened = number,
                ),
              ),
            ),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(JourneyTree));
      final leaf = TreeLayout.instance.leaves.firstWhere((l) => l.number == 9);
      await tester.tapAt(box.localToGlobal(leaf.centre));
      await tester.pump(const Duration(milliseconds: 120));

      expect(opened, 9);
      expect(_painter(tester).motion!.rustleOf(9), isNot(0));
    });
  });
}
