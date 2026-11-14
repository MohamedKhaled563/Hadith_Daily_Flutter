import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/pill_tabs.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/features/journey/journey_numbers.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool dark = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );

const _numbers = JourneyNumbers(
  streak: StreakResult(
    current: 11,
    best: 11,
    graceBanked: 1,
    presentToday: true,
  ),
  bestThisWeek: 5,
  weekPoints: 65,
  allPoints: 185,
  memorized: 4,
  canShare: true,
);

/// The semantics node a screen reader (and uiautomator) sees with exactly
/// [label]: none when the label was merged into a bigger node.
SemanticsNode? _node(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  if (finder.evaluate().isEmpty) return null;
  return tester.getSemantics(finder.first);
}

void main() {
  group('the numbers card', () {
    testWidgets('the «كيف تُحسب؟» button is a node of its own, button-sized',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _numbers);

      final how = _node(tester, 'كيف تُحسب؟');
      expect(how, isNotNull, reason: 'not merged into the card');
      expect(how!.rect.width, lessThanOrEqualTo(60));
      expect(how.rect.height, lessThanOrEqualTo(60));
      semantics.dispose();
    });

    testWidgets('each figure is read on its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _numbers);

      for (final label in [
        'الاستمرارية: ١١ يوماً',
        'أفضل استمرارية: ٥ أيام',
        'نقاط الأسبوع: ٦٥ نقطة',
        'كل نقاطك: ١٨٥ نقطة',
        'حفظت: ٤ / ٤٢ حديثاً',
      ]) {
        expect(_node(tester, label), isNotNull, reason: label);
      }
      semantics.dispose();
    });

    testWidgets('fits a narrow phone with large text, in both themes',
        (tester) async {
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        await _pump(tester, _numbers, dark: dark);
        expect(tester.takeException(), isNull, reason: 'dark: $dark');
      }
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    testWidgets('«كيف تُحسب؟» opens the explanation', (tester) async {
      await _pump(tester, _numbers);
      await tester.tap(find.byTooltip('كيف تُحسب؟'));
      await tester.pumpAndSettle();
      expect(find.text('كيف تُحسب أرقامك؟'), findsOneWidget);
      expect(find.text('رسالة لك يقبلها المشرف'), findsOneWidget);
    });
  });

  group('the sliding tabs', () {
    testWidgets('each tab is its own selectable button, and switches',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => PillTabs<int>(
                  values: const [0, 1, 2],
                  labelOf: (i) => ['النقاط', 'المشاركة', 'الحفظ'][i],
                  selected: selected,
                  onSelected: (i) => setState(() => selected = i),
                ),
              ),
            ),
          ),
        ),
      );

      for (final label in ['النقاط', 'المشاركة', 'الحفظ']) {
        expect(_node(tester, label), isNotNull, reason: label);
      }
      expect(_node(tester, 'النقاط'), isSemantics(isSelected: true));
      await tester.tap(find.text('الحفظ'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(_node(tester, 'الحفظ'), isSemantics(isSelected: true));
      semantics.dispose();
    });
  });
}
