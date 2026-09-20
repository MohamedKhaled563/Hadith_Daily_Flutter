import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';

/// Arabic script has no italic form. Slanting it is a Latin convention, and
/// no oblique Amiri is bundled — so `FontStyle.italic` did not select a face,
/// it asked the engine to shear the glyphs of the one hadith screen that sets
/// scripture. This is the app's one outright typographic error, and it is
/// cheap to keep it gone.

const _hadith = Hadith(
  number: 1,
  title: 'الأعمال بالنيات',
  text: 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
  isnad: 'عَنْ عُمَرَ رَضِيَ اللهُ عَنْهُ قَالَ',
  explanation: 'شرح مختصر.',
  mukhrij: 'البخاري ومسلم',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  Future<void> pumpDetail(WidgetTester tester, ThemeMode mode) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HadithDetailScreen(hadith: _hadith),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('no Arabic text is set in faux italic — $mode', (tester) async {
      await pumpDetail(tester, mode);

      // The isnad is on screen, so this is asserting about text that is
      // actually rendered rather than passing on an empty tree.
      expect(find.textContaining('عَنْ عُمَرَ'), findsOneWidget);

      final slanted = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.fontStyle == FontStyle.italic)
          .map((t) => t.data ?? '')
          .toList();

      expect(
        slanted,
        isEmpty,
        reason: 'these are sheared by the engine, not set in an italic face: '
            '$slanted',
      );
    });
  }
}
