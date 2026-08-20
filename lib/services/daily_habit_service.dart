import 'package:shared_preferences/shared_preferences.dart';

class DailyHabitService {
  DailyHabitService._();
  static final instance = DailyHabitService._();

  static const _readDatesKey = 'daily_read_dates';
  static const _historyKey = 'hadith_history_numbers';
  static const _maxHistory = 30;

  Future<void> markRead({required int hadithNumber, DateTime? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final day = _dateKey(date ?? DateTime.now());
    final dates = prefs.getStringList(_readDatesKey) ?? <String>[];
    if (!dates.contains(day)) {
      dates.add(day);
      dates.sort();
      if (dates.length > 120) {
        dates.removeRange(0, dates.length - 120);
      }
      await prefs.setStringList(_readDatesKey, dates);
    }

    final history = prefs.getStringList(_historyKey) ?? <String>[];
    final number = hadithNumber.toString();
    history.remove(number);
    history.insert(0, number);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setStringList(_historyKey, history);
  }

  Future<bool> hasReadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = prefs.getStringList(_readDatesKey) ?? <String>[];
    return dates.contains(_dateKey(DateTime.now()));
  }

  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = (prefs.getStringList(_readDatesKey) ?? <String>[]).toSet();
    var cursor = _stripTime(DateTime.now());
    var streak = 0;

    while (dates.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<List<int>> getHistoryNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_historyKey) ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }


  Future<List<bool>> getLast7DaysStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = (prefs.getStringList(_readDatesKey) ?? <String>[]).toSet();
    final today = _stripTime(DateTime.now());
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return dates.contains(_dateKey(day));
    });
  }

  Future<int> getTotalReadDays() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_readDatesKey) ?? <String>[]).length;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _stripTime(DateTime date) => DateTime(date.year, date.month, date.day);
}
