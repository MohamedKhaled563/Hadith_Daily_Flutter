import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/tap_target.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/daily_tip_service.dart';
import 'package:hadith_app/features/favorites/favorites_screen.dart';

/// A message saved from «مجتمع الحديث» has to land in the same Favourites
/// list as one saved from «رسائل اليوم». The repository always supported
/// that; nothing in the community flow ever called it, because the whole
/// flow had share and like and no bookmark at all.

CommunityPost post({
  String id = 'post-1',
  String message = 'الصبر ضياء، وما أوتي أحد عطاءً خيراً وأوسع من الصبر.',
  int hadithNumber = 3,
}) =>
    CommunityPost(
      id: id,
      authorName: 'أمira',
      message: message,
      hadithNumber: hadithNumber,
    );

void main() {
  late HadithRepository repo;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = HadithRepository();
    await repo.load();
    // load() seeds a few favourites so a first launch is not empty; clear
    // them so each test starts from a known, empty list.
    for (final insight in repo.getFavoriteInsights().toList()) {
      repo.toggleFavoriteInsight(insight);
    }
  });

  test('a community post can be saved, and shows up in the messages list',
      () async {
    final insight = post().toInsight();

    expect(repo.isInsightFavorite(insight), isFalse);
    expect(repo.getFavoriteInsights(), isEmpty);

    repo.toggleFavoriteInsight(insight);

    expect(repo.isInsightFavorite(insight), isTrue);
    expect(
      repo.getFavoriteInsights().map((i) => i.message),
      contains(post().message),
      reason: 'the Favourites messages tab reads exactly this list',
    );
  });

  test('un-saving removes it again', () async {
    final insight = post().toInsight();
    repo.toggleFavoriteInsight(insight);
    repo.toggleFavoriteInsight(insight);

    expect(repo.isInsightFavorite(insight), isFalse);
    expect(repo.getFavoriteInsights(), isEmpty);
  });

  test('the same text from either source is one favourite, not two', () async {
    // Favourites are keyed on hadithNumber + text, deliberately — the same
    // reflection can reach a reader as a community post *and* as that day's
    // message, and saving it twice should not produce two entries.
    final fromCommunity = post().toInsight();
    final fromDailyMessage = const DailyTip(
      id: 'tip-9',
      sourceCollection: 'communityMessages',
      text: 'الصبر ضياء، وما أوتي أحد عطاءً خيراً وأوسع من الصبر.',
      hadithNumber: 3,
      category: 'تأمّل',
    ).toInsight();

    repo.toggleFavoriteInsight(fromCommunity);

    expect(
      repo.isInsightFavorite(fromDailyMessage),
      isTrue,
      reason: 'the daily-message card must show it as already saved',
    );
    expect(repo.getFavoriteInsights(), hasLength(1));
  });

  test('a community post survives a reload from disk', () async {
    repo.toggleFavoriteInsight(post().toInsight());

    // HadithRepository is a singleton, so constructing a second one would
    // hand back the same object and prove nothing. What makes this real is
    // that load() -> _loadFavorites() *replaces* the in-memory map with
    // whatever SharedPreferences holds: if the write path were broken, the
    // reload would drop the favourite rather than keep it.
    final stored = (await SharedPreferences.getInstance())
        .getStringList('favoriteInsightTexts')!;
    expect(
      stored.map((e) => json.decode(e) as Map<String, dynamic>),
      contains(
        allOf(
          containsPair('arabic', post().message),
          containsPair('sourceCollection', 'communityMessages'),
        ),
      ),
      reason: 'the community post has to reach disk, with its source',
    );

    await repo.load();

    expect(repo.isInsightFavorite(post().toInsight()), isTrue);
    expect(
      repo.getFavoriteInsights().map((i) => i.message),
      contains(post().message),
    );
  });

  test('it carries its source so the card can label it', () async {
    final insight = post().toInsight();
    expect(insight.sourceCollection, 'communityMessages');
    expect(insight.category, 'مشاركة مجتمعية');
    expect(insight.id, 'post-1');
  });

  testWidgets('a saved message opens when the card itself is tapped',
      (tester) async {
    // The card carried its own text, its own pill and three glyphs, and was
    // the one thing on the screen that did nothing when you touched it —
    // opening the message needed a 20px fullscreen icon between two others.
    repo.toggleFavoriteInsight(post().toInsight());

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(post().message), findsOneWidget);

    final card = find.ancestor(
      of: find.textContaining(post().message),
      matching: find.byType(PressableSurface),
    );
    expect(card, findsOneWidget,
        reason: 'the whole card has to be the tap target, not one glyph');
    expect(
      tester.widget<PressableSurface>(card).onTap,
      isNotNull,
      reason: 'a PressableSurface with a null onTap renders its child bare, '
          'which is the old do-nothing card again',
    );

    // The glyph it replaces must be gone, or there are two controls for one
    // action sitting on the same card.
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
  });
}
