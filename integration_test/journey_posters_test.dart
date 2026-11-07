import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/share/share_service.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/journey/journey_posters.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real off-stage render, on a device: the size that reaches the share
/// sheet, and the artwork that a poster only has if it was decoded in time.
/// Each poster is left in the app's cache folder to be looked at:
///
///     adb exec-out run-as com.prodktstudio.tayebqalbak cat cache/poster-tree-story.png > out.png
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext host;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  Future<void> check(
    WidgetTester tester,
    String name,
    Widget poster,
    PosterFormat format,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      final bytes = await ShareService.renderPoster(
        context: host,
        poster: poster,
        size: format.size,
      );

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, (format.size.width * 3).round());
      expect(image.height, (format.size.height * 3).round());

      // The first poster of a session used to lose its corner artwork. The
      // botanicals are the only thing painted out at the very edge, so the
      // corners show whether they arrived.
      final pixels = (await image.toByteData())!;
      bool hasArtwork(int fromX, int fromY) {
        for (var y = fromY; y < fromY + 300; y += 7) {
          for (var x = fromX; x < fromX + 300; x += 7) {
            final at = (y * image.width + x) * 4;
            final red = pixels.getUint8(at);
            final green = pixels.getUint8(at + 1);
            if (green > red + 4) return true;
          }
        }
        return false;
      }

      expect(hasArtwork(image.width - 300, 0), isTrue,
          reason: 'top corner artwork on $name');
      expect(hasArtwork(0, image.height - 300), isTrue,
          reason: 'bottom corner artwork on $name');

      final dir = await getTemporaryDirectory();
      await File('${dir.path}/poster-$name.png').writeAsBytes(bytes);
    });
  }

  final data = JourneyData(hadith: {
    for (var n = 1; n <= 15; n++)
      n: const HadithProgress(fullOn: '2026-11-06'),
    16: const HadithProgress(textOn: '2026-11-07'),
  });

  for (final format in PosterFormat.values) {
    testWidgets('the tree renders as a ${format.name} poster', (tester) async {
      await check(
        tester,
        'tree-${format.name}',
        TreePoster(format: format, data: data),
        format,
      );
    });

    testWidgets('a hadith renders as a ${format.name} poster', (tester) async {
      await check(
        tester,
        'hadith-${format.name}',
        HadithPoster(
          format: format,
          hadith: HadithRepository().getByNumber(16)!,
        ),
        format,
      );
    });
  }

  testWidgets('the longest title renders with a name on it', (tester) async {
    const format = PosterFormat.feed;
    await check(
      tester,
      'hadith-long',
      HadithPoster(
        format: format,
        hadith: HadithRepository().getByNumber(41)!,
        name: 'سارة',
      ),
      format,
    );
  });
}
