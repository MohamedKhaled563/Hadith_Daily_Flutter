import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:hadith_app/features/journey/journey_ring.dart';
import 'package:hadith_app/features/journey/today_steps_screen.dart';

const _hadith = Hadith(
  number: 7,
  title: 'الدين النصيحة',
  text: 'نص',
  explanation: 'شرح',
);

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

void main() {
  group('the steps ring', () {
    testWidgets('a day with nothing done shows a leaf, not a zero',
        (tester) async {
      await _pump(tester, const StepsRing(done: 0));
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
      expect(find.text('٠'), findsNothing);
    });

    for (final done in [1, 2, 3]) {
      testWidgets('counts $done in the middle', (tester) async {
        await _pump(tester, StepsRing(done: done));
        await tester.pumpAndSettle();
        expect(find.text(['١', '٢', '٣'][done - 1]), findsOneWidget);
      });
    }

    testWidgets('never counts past three', (tester) async {
      await _pump(tester, const StepsRing(done: 5));
      await tester.pumpAndSettle();
      expect(find.text('٣'), findsOneWidget);
    });

    test('is described as a count of three', () {
      expect(StepsRing.describe(2), '٢ من ٣ خطوات اليوم');
    });

    testWidgets('draws in dark mode too, at any size', (tester) async {
      for (final size in [32.0, 44.0, 112.0]) {
        await _pump(tester, StepsRing(done: 3, size: size), dark: true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final circle = tester.getSize(
          find
              .descendant(
                of: find.byType(StepsRing),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(circle, Size.square(size), reason: 'a circle, not an oval');
      }
    });
  });

  group('the steps button on رحلتي', () {
    final cases = {
      const DaySteps(message: false, hadith: false, wrote: false):
          'ابدأ برسالة اليوم',
      const DaySteps(message: true, hadith: false, wrote: false): 'بقيت خطوتان',
      const DaySteps(message: true, hadith: true, wrote: false):
          'بقيت خطوة واحدة',
      const DaySteps(message: true, hadith: true, wrote: true):
          JourneyCopy.stepsAllDone,
    };
    for (final MapEntry(key: steps, value: line) in cases.entries) {
      testWidgets('says «$line» at ${steps.done} of 3', (tester) async {
        var opened = false;
        await _pump(
          tester,
          TodayStepsButton(steps: steps, onTap: () => opened = true),
        );
        expect(find.text('خطوات اليوم'), findsOneWidget);
        expect(find.text(line), findsOneWidget);
        await tester.tap(find.text('خطوات اليوم'));
        expect(opened, isTrue);
      });
    }
  });

  group('the steps', () {
    testWidgets('each step opens its own screen', (tester) async {
      var message = 0;
      int? hadith;
      await _pump(
        tester,
        TodaySteps(
          steps: const DaySteps(message: false, hadith: false, wrote: false),
          next: _hadith,
          writeAbout: _hadith,
          onOpenMessage: () => message++,
          onOpenHadith: (number) => hadith = number,
        ),
      );

      expect(find.text('اقرأ حديث «الدين النصيحة»'), findsOneWidget);
      expect(find.text('ما بقي معك من «الدين النصيحة»'), findsOneWidget);

      await tester.tap(find.text('اقرأ رسالة اليوم'));
      expect(message, 1);
      await tester.tap(find.text('اقرأ حديث «الدين النصيحة»'));
      expect(hadith, 7);
    });

    testWidgets('a done step shows a tick and loses its arrow', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        TodaySteps(
          steps: const DaySteps(message: true, hadith: true, wrote: false),
          next: _hadith,
          writeAbout: _hadith,
          onOpenMessage: () {},
          onOpenHadith: (_) {},
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('أتممت حديث اليوم'), findsOneWidget);
      expect(find.text('التالي: «الدين النصيحة»'), findsOneWidget);
      // Only the writing step, still to do, points onward.
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('اقرأ رسالة اليوم، تمّت'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('after the Forty, the reading step says so', (tester) async {
      await _pump(
        tester,
        TodaySteps(
          steps: const DaySteps(message: false, hadith: false, wrote: false),
          next: null,
          writeAbout: _hadith,
          onOpenMessage: () {},
          onOpenHadith: (_) {},
        ),
      );
      expect(find.text('أتممت الأربعين'), findsOneWidget);
    });
  });
}
