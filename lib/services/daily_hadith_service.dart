import '../data/hadith_repository.dart';
import '../models/hadith.dart';

/// Deterministically maps a calendar day to one hadith.
/// The same date always returns the same hadith for every user.
class DailyHadithService {
  static Future<Hadith> getForToday() => getForDate(DateTime.now());

  static Future<Hadith> getForDate(DateTime date) async {
    final all = await HadithRepository.instance.loadAll();
    if (all.isEmpty) throw StateError('No hadith data available.');
    final index = _dayOfYear(date) % all.length;
    return all[index];
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }
}
