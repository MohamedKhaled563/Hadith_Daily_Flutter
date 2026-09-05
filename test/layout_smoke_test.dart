import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/hadith/hadith_list_screen.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';

/// Device sizes that previously broke the Home hero (F-07). 360x640 is the
/// stock small Android phone the audit measured a 6dp deficit on.
const _sizes = <String, Size>{
  '360x640 (small)': Size(360, 640),
  '390x844 (iPhone)': Size(390, 844),
  '320x568 (SE)': Size(320, 568),
  '412x915 (large)': Size(412, 915),
};

Widget _wrap(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
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
    home: child,
  );
}

Future<void> _pumpAt(
  WidgetTester tester,
  Widget widget,
  Size size, {
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: _wrap(widget, mode: mode),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // HomeScreen keeps every tab mounted (IndexedStack) and its
    // CommunityScreen/NotificationScheduler children reach for
    // FirebaseFirestore.instance as soon as they build — register a fake
    // default app so that succeeds instead of throwing [core/no-app].
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await HadithRepository().load();
  });

  group('Home renders without overflow', () {
    for (final entry in _sizes.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpAt(tester, const HomeScreen(), entry.value);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Home survives large text scale', () {
    for (final scale in [1.3, 1.6]) {
      testWidgets('360x640 @ ${scale}x', (tester) async {
        await _pumpAt(
          tester,
          const HomeScreen(),
          const Size(360, 640),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Home renders in dark mode', (tester) async {
    await _pumpAt(
      tester,
      const HomeScreen(),
      const Size(360, 640),
      mode: ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hadith list and detail render without overflow', (tester) async {
    await _pumpAt(tester, const HadithListScreen(), const Size(360, 640));
    expect(tester.takeException(), isNull);

    final hadith = HadithRepository().getAll().first;
    await _pumpAt(
      tester,
      HadithDetailScreen(hadith: hadith),
      const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily message card renders without overflow', (tester) async {
    final repo = HadithRepository();
    final insight = repo.getRandomInsight();
    expect(insight, isNotNull, reason: 'insights.json should be bundled');

    await _pumpAt(
      tester,
      DailyMessageScreen(
        insight: insight!,
        hadith: repo.getByNumber(insight.hadithNumber),
      ),
      const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
  });

  test('bundled content loaded from the workbook export', () {
    final repo = HadithRepository();

    expect(repo.getAll(), hasLength(42));
    expect(repo.insights, hasLength(246));

    // Numbering is complete and unique.
    expect(
      repo.getAll().map((h) => h.number).toList()..sort(),
      List.generate(42, (i) => i + 1),
    );

    for (final hadith in repo.getAll()) {
      expect(hadith.title.trim(), isNotEmpty, reason: '#${hadith.number} title');
      expect(hadith.text.trim(), isNotEmpty, reason: '#${hadith.number} text');
      expect(hadith.reference.trim(), isNotEmpty,
          reason: '#${hadith.number} reference');
      expect(hadith.explanation.trim(), isNotEmpty,
          reason: '#${hadith.number} explanation');
    }

    // Daily messages cover every hadith since the workbook migration
    // (7fc5798) replaced the old 22-hadith source with one covering all 42.
    final covered = repo.insights.map((i) => i.hadithNumber).toSet();
    expect(covered, List.generate(42, (i) => i + 1).toSet());
  });

  testWidgets('Theme toggle repaints pushed screens (F-04)', (tester) async {
    final state = AppStateController();
    state.setThemeMode(ThemeMode.light);

    final hadith = HadithRepository().getAll().first;

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HadithDetailScreen(hadith: hadith),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color titleColour() {
      final text = tester.widget<Text>(find.text(hadith.title).first);
      return text.style!.color!;
    }

    final lightColour = titleColour();

    state.toggleTheme();
    await tester.pumpAndSettle();

    // Colour must actually change: the screen used to read isDarkMode off the
    // singleton imperatively and never rebuilt.
    expect(titleColour(), isNot(equals(lightColour)));

    state.setThemeMode(ThemeMode.light);
  });
}
