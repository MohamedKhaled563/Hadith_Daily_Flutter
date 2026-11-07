import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/journey/journey_posters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A poster has a fixed canvas, so anything too long clips silently on an
/// image the reader has already sent. Every hadith title goes through both
/// shapes here, since the overflow only shows up in a layout.
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
    for (var n = 1; n <= 15; n++)
      n: const HadithProgress(fullOn: '2026-11-06'),
  });

  for (final format in PosterFormat.values) {
    testWidgets('every hadith fits the ${format.name} poster', (tester) async {
      for (final hadith in HadithRepository().hadiths) {
        await layOut(
          tester,
          HadithPoster(
            format: format,
            hadith: hadith,
            name: 'اسم طويل جداً لقارئ يحب الأسماء الطويلة كثيراً',
          ),
          format.size,
        );
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
    final format = PosterFormat.feed;
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
    final format = PosterFormat.story;
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
      expect(JourneyCopy.hadithCaption('لا تغضب', 16, 'https://x.example'),
          contains('https://x.example'));
    });

    test('leave the line out when there is none', () {
      expect(JourneyCopy.treeCaption(15, null), isNot(contains('null')));
      expect(JourneyCopy.hadithCaption('لا تغضب', 16, null),
          isNot(contains('null')));
    });

    test('read properly before the first hadith is finished', () {
      expect(JourneyCopy.treeCaption(0, null), isNot(contains('٠')));
    });
  });
}
