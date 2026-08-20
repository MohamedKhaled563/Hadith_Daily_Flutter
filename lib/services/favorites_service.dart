import 'package:shared_preferences/shared_preferences.dart';

/// Stores favorite hadith numbers locally on the device.
/// No account/auth needed for V1 — everything lives in SharedPreferences.
class FavoritesService {
  FavoritesService._internal();
  static final FavoritesService instance = FavoritesService._internal();

  static const _key = 'favorite_hadith_numbers';

  Set<int>? _cache;

  Future<Set<int>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    _cache = list.map(int.parse).toSet();
    return _cache!;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _cache!.map((e) => e.toString()).toList(),
    );
  }

  Future<bool> isFavorite(int hadithNumber) async {
    final set = await _load();
    return set.contains(hadithNumber);
  }

  Future<Set<int>> getAll() async => Set.unmodifiable(await _load());

  /// Returns the new favorite state (true = now favorited).
  Future<bool> toggle(int hadithNumber) async {
    final set = await _load();
    late final bool nowFavorite;
    if (set.contains(hadithNumber)) {
      set.remove(hadithNumber);
      nowFavorite = false;
    } else {
      set.add(hadithNumber);
      nowFavorite = true;
    }
    await _persist();
    return nowFavorite;
  }
}
