import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the reader's tree last showed them: which leaves had opened, which
/// fruit had grown, and on which day. The tree compares it with the journey
/// to know what to grow in front of the reader, so a leaf opens once, when
/// they come back to it, and not on every visit.
@immutable
class TreeSeen {
  const TreeSeen({
    this.leaves = const {},
    this.fruit = const {},
    this.day,
  });

  final Set<int> leaves;
  final Set<int> fruit;

  /// The journey day the tree last greeted the reader, or null if it never
  /// has.
  final String? day;
}

/// Keeps [TreeSeen] on the phone, one copy per account, so two people
/// signed in on the same phone each see their own leaves open. A guest's
/// keys carry no suffix.
class TreeMemory {
  const TreeMemory._();

  static const _leavesKey = 'journey.tree.leaves';
  static const _fruitKey = 'journey.tree.fruit';
  static const _dayKey = 'journey.tree.day';

  static String _perAccount(String key, String? account) =>
      (account == null || account.isEmpty) ? key : '$key.$account';

  static Set<int> _numbers(List<String>? stored) => {
        for (final entry in stored ?? const <String>[])
          if (int.tryParse(entry) case final number?) number,
      };

  static Future<TreeSeen> load(String? account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return TreeSeen(
        leaves: _numbers(prefs.getStringList(_perAccount(_leavesKey, account))),
        fruit: _numbers(prefs.getStringList(_perAccount(_fruitKey, account))),
        day: prefs.getString(_perAccount(_dayKey, account)),
      );
    } catch (error) {
      // Worst case the leaves open again; never worth stopping the tree.
      debugPrint('TreeMemory: not read: $error');
      return const TreeSeen();
    }
  }

  static Future<void> save(String? account, TreeSeen seen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> listed(Set<int> numbers) =>
          [for (final number in numbers.toList()..sort()) '$number'];
      await prefs.setStringList(
        _perAccount(_leavesKey, account),
        listed(seen.leaves),
      );
      await prefs.setStringList(
        _perAccount(_fruitKey, account),
        listed(seen.fruit),
      );
      final day = seen.day;
      if (day != null) {
        await prefs.setString(_perAccount(_dayKey, account), day);
      }
    } catch (error) {
      debugPrint('TreeMemory: not saved: $error');
    }
  }
}
