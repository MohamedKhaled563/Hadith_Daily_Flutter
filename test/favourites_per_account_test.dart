import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/favorites_store.dart';

/// Favourites belong to the account, not the phone.
///
/// They used to live in SharedPreferences, seeded with hadiths 1, 2 and 12 so
/// "a first launch doesn't look empty" — and since a fresh install has no
/// stored list to replace the seed, every new install on Android and iOS
/// opened with three favourites nobody had chosen. Two accounts on one phone
/// also shared one list, and signing out kept it.

const _insight = Insight(hadithNumber: 3, arabic: 'الصبر ضياء.', english: '');

void main() {
  late HadithRepository repo;
  late InMemoryFavoritesStore store;
  String? uid;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = HadithRepository();
    await repo.load();
    store = InMemoryFavoritesStore();
    uid = null;
    repo.debugOverrideFavorites(store: store, currentUid: () => uid);
  });

  /// Signs [who] in (null signs out) and lets their list arrive from the
  /// store, the way the Firestore snapshot does after a real sign-in.
  Future<void> signIn(String? who) async {
    uid = who;
    repo.setUser(who);
    await pumpEventQueue();
  }

  test('a new account starts with no favourites', () async {
    await signIn('new-reader');
    expect(repo.getFavoriteHadiths(), isEmpty);
    expect(repo.getFavoriteInsights(), isEmpty);
  });

  test('a guest has none and cannot add any', () {
    expect(repo.hasFavoritesAccount, isFalse);
    expect(() => repo.toggleFavoriteHadith(1), throwsStateError);
    expect(() => repo.toggleFavoriteInsight(_insight), throwsStateError);
    expect(repo.getFavoriteHadiths(), isEmpty);
  });

  test('signing out clears them, signing back in restores them', () async {
    await signIn('reader-a');
    repo.toggleFavoriteHadith(7);
    repo.toggleFavoriteInsight(_insight);

    await signIn(null);
    expect(repo.getFavoriteHadiths(), isEmpty);
    expect(repo.getFavoriteInsights(), isEmpty);

    await signIn('reader-a');
    expect(repo.isHadithFavorite(7), isTrue);
    expect(repo.isInsightFavorite(_insight), isTrue);
  });

  test('two accounts on one phone keep separate lists', () async {
    await signIn('reader-a');
    repo.toggleFavoriteHadith(7);

    await signIn('reader-b');
    expect(repo.isHadithFavorite(7), isFalse);
    repo.toggleFavoriteHadith(9);

    await signIn('reader-a');
    expect(repo.favoriteHadithNumbers, {7});
  });

  test('saving right after sign-in works before the auth listener catches up',
      () {
    // The sign-in sheet closes and the reader's tap goes through; the
    // repository must not refuse just because setUser has not run yet.
    uid = 'reader-a';
    repo.toggleFavoriteHadith(4);
    expect(repo.isHadithFavorite(4), isTrue);
  });

  test('the old on-device favourites are cleared on load', () async {
    SharedPreferences.setMockInitialValues({
      'favoriteHadithNumbers': ['1', '2', '12'],
      'favoriteInsightTexts': <String>[],
    });
    await repo.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('favoriteHadithNumbers'), isFalse);
    expect(prefs.containsKey('favoriteInsightTexts'), isFalse);
  });
}
