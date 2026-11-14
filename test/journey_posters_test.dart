import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/journey/journey_posters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A poster has a fixed canvas, so anything too long clips silently on an
/// image the reader has already sent. Every milestone message goes through
/// both shapes here, since the overflow only shows up in a layout.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  Future<void> layOut(WidgetTester tester, Widget poster, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.noScaling),
        child: Center(child: poster),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  final data = JourneyData(hadith: {
    for (var n = 1; n <= 15; n++) n: const HadithProgress(fullOn: '2026-11-06'),
  });

  for (final format in PosterFormat.values) {
    testWidgets('every milestone fits the ${format.name} poster',
        (tester) async {
      for (final mark in kJourneyMilestones) {
        await layOut(
          tester,
          MilestonePoster(
            format: format,
            milestone: mark,
            name: 'اسم طويل جداً لقارئ يحب الأسماء الطويلة كثيراً',
          ),
          format.size,
        );
        expect(find.text(JourneyCopy.milestone(mark).title), findsOneWidget);
        expect(find.text(JourneyCopy.milestone(mark).body), findsOneWidget);
      }
    });

    testWidgets('the harvest fits the ${format.name} poster, big or not',
        (tester) async {
      for (final (streak, best, points) in [
        (0, 0, 0),
        (1, 1, 2),
        (365, 7, 450)
      ]) {
        await layOut(
          tester,
          HarvestPoster(
            format: format,
            harvest: Harvest(
              days: 7,
              minutes: 90,
              lastWeekMinutes: 0,
              streak: streak,
              bestRun: best,
              points: points,
            ),
            weekLabel: 'أسبوع ١٤–٢٠ نوفمبر',
            name: 'اسم طويل جداً لقارئ يحب الأسماء الطويلة كثيراً',
          ),
          format.size,
        );
        for (final label in ['الاستمرارية', 'أفضل استمرارية', 'نقاط الأسبوع']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('حصاد أسبوعي'), findsOneWidget);
      }
    });

    testWidgets('the journey fits the ${format.name} poster, big or not',
        (tester) async {
      for (final (best, points, held) in [
        (0, 0, 0),
        (1, 2, 1),
        (365, 9999, 42)
      ]) {
        await layOut(
          tester,
          JourneyHarvestPoster(
            format: format,
            bestStreak: best,
            points: points,
            memorized: held,
            name: 'اسم طويل جداً لقارئ يحب الأسماء الطويلة كثيراً',
          ),
          format.size,
        );
        for (final label in ['أفضل استمرارية', 'كل نقاطي', 'حفظت']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('حصاد رحلتي'), findsOneWidget);
      }
    });

    testWidgets('a full board fits the ${format.name} poster', (tester) async {
      for (final values in [true, false]) {
        await layOut(
          tester,
          BoardPoster(
            format: format,
            weekLabel: 'أسبوع ٢٨ نوفمبر – ٤ ديسمبر',
            listLabel: values ? 'المشاركة' : 'الحفظ',
            rows: [
              for (var i = 1; i <= 10; i++)
                PosterBoardRow(
                  name: 'قارئ باسم مستعار طويل نوعاً ما $i',
                  value: values ? '١٢٣٤ نقطة' : null,
                ),
            ],
          ),
          format.size,
        );
        expect(find.textContaining('قارئ باسم مستعار'), findsNWidgets(10));
        expect(find.text(JourneyCopy.posterFindUs), findsOneWidget);
      }
    });

    testWidgets('the tree fits the ${format.name} poster, name or not',
        (tester) async {
      for (final name in [null, 'سارة']) {
        await layOut(
          tester,
          TreePoster(format: format, data: data, name: name),
          format.size,
        );
      }
    });
  }

  testWidgets('no name shows unless the reader passes one', (tester) async {
    const format = PosterFormat.feed;
    await layOut(
      tester,
      TreePoster(format: format, data: data),
      format.size,
    );
    expect(find.text('سارة'), findsNothing);

    await layOut(
      tester,
      TreePoster(format: format, data: data, name: 'سارة'),
      format.size,
    );
    expect(find.text('سارة'), findsOneWidget);
  });

  testWidgets('every poster says how to find the app', (tester) async {
    const format = PosterFormat.story;
    await layOut(
      tester,
      TreePoster(format: format, data: data),
      format.size,
    );
    expect(find.text(JourneyCopy.posterFindUs), findsOneWidget);
  });

  group('captions', () {
    test('carry the link when there is one', () {
      expect(JourneyCopy.treeCaption(15, 'https://x.example'),
          contains('https://x.example'));
      expect(JourneyCopy.milestoneCaption(5, 'https://x.example'),
          contains('https://x.example'));
    });

    test('leave the line out when there is none', () {
      expect(JourneyCopy.treeCaption(15, null), isNot(contains('null')));
      expect(JourneyCopy.milestoneCaption(5, null), isNot(contains('null')));
    });

    test('a milestone sends its own message, word for word', () {
      for (final mark in kJourneyMilestones) {
        final message = JourneyCopy.milestone(mark);
        expect(
          JourneyCopy.milestoneCaption(mark, null),
          '${message.title}\n${message.body}',
        );
      }
    });

    test('the journey leaves memorizing out until there is some', () {
      final none = JourneyCopy.journeyCaption(
        bestStreak: 3,
        points: 40,
        memorized: 0,
      );
      expect(none, isNot(contains('حفظت')));
      expect(none, isNot(contains('null')));
      expect(
        JourneyCopy.journeyCaption(
          bestStreak: 3,
          points: 40,
          memorized: 2,
          link: 'https://x.example',
        ),
        allOf(contains('حفظت ٢ من ٤٢'), contains('https://x.example')),
      );
    });

    test('the board says which week, and the way to the app', () {
      final caption = JourneyCopy.boardCaption('٧ – ١٣ نوفمبر', 'https://x');
      expect(caption, contains('٧ – ١٣ نوفمبر'));
      expect(caption, contains('https://x'));
    });

    test('read properly before the first hadith is finished', () {
      expect(JourneyCopy.treeCaption(0, null), isNot(contains('٠')));
    });
  });
}
