import '../data/hadith_repository.dart';
import '../models/hadith.dart';

/// Picks "today's hadith" deterministically from the date, so every user
/// sees the same hadith on the same calendar day (like a real "tip of the
/// day"), and it's stable if they reopen the app later the same day.
class DailyHadithService {
  static Future<Hadith> getForToday() async {
    final all = await HadithRepository.instance.loadAll();
    final dayOfYear = _dayOfYear(DateTime.now());
    final index = dayOfYear % all.length;
    return all[index];
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }
}
