import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/app_snack.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/favorites/favorites_screen.dart';

/// Flutter resolves a SnackBar's `persist` as `persist ?? action != null`, so
/// attaching an undo to a snackbar quietly turns off its timeout: it ignores
/// its own duration and stays until the reader taps the action — the one
/// control that *reverses* what they just did. Every snack in this app that
/// offers an undo was affected, and the removal snack in Favourites is the
/// one a reader meets first.
///
/// Both halves are pinned here: the snack has to leave on its own, and what
/// it announced has to stay gone.

const _text = 'الصبر ضياء.';

Insight get _saved => CommunityPost(
      id: 'p1',
      authorName: 'أميرة',
      message: _text,
      hadithNumber: 3,
    ).toInsight();

void main() {
  late HadithRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = HadithRepository();
    await repo.load();
    for (final i in repo.getFavoriteInsights().toList()) {
      repo.toggleFavoriteInsight(i);
    }
    repo.toggleFavoriteInsight(_saved);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: FavoritesScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the removal snack clears itself', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.bookmark_remove_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تمت الإزالة من المحفوظات'), findsOneWidget);

    // Frame by frame rather than one 5-second jump: ScaffoldMessenger only
    // arms its dismiss timer during a build that happens *after* the entry
    // animation completes, so a single long pump skips the frame that starts
    // the clock and would fail against a perfectly healthy snackbar.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('تمت الإزالة من المحفوظات'), findsNothing,
        reason: 'a 3-second snack still on screen after 6 is a stuck snack');
  });

  testWidgets('the removed message does not come back', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.bookmark_remove_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 6));

    expect(repo.isInsightFavorite(_saved), isFalse);
    expect(find.textContaining(_text), findsNothing);

    // The cold-start path: load() replaces the in-memory map from disk, so a
    // removal that never reached disk reappears exactly here.
    await repo.load();
    expect(repo.isInsightFavorite(_saved), isFalse,
        reason: 'the removal has to survive a restart');
  });

  testWidgets('an undo snack leaves on its own, like every other one',
      (tester) async {
    // The unit-level version of the same rule, away from any one screen: a
    // regression here would put the timeout back off for the whole app.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAppSnack(
                context,
                'مع تراجع',
                action: undoAction(context, () {}),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('مع تراجع'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget,
        reason: 'the undo itself must still be offered while it is up');

    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('مع تراجع'), findsNothing);
  });
}
