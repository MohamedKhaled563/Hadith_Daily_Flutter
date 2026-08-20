import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/hadith.dart';

/// Loads the 40 (42) Hadith Nawawi from the bundled asset JSON.
/// The file lives at assets/data/hadiths.json and is loaded once,
/// then cached in memory for the lifetime of the app.
class HadithRepository {
  HadithRepository._internal();
  static final HadithRepository instance = HadithRepository._internal();

  List<Hadith>? _cache;

  Future<List<Hadith>> loadAll() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/data/hadiths.json');
    final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;

    final hadiths = jsonList
        .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    _cache = hadiths;
    return hadiths;
  }

  Future<Hadith?> byNumber(int number) async {
    final all = await loadAll();
    try {
      return all.firstWhere((h) => h.number == number);
    } catch (_) {
      return null;
    }
  }
}
