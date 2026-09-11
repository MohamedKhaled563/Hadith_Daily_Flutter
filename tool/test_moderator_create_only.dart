// Standalone diagnostic for the moderator-vs-admin bulk-upload permission
// split in lib/features/dashboard/bulk_add_page.dart: moderators may only
// add new rows through the Excel round trip; any update or delete their
// sheet implies must be dropped, never applied.
//
// This mirrors SheetDiff's shape locally (a plain Dart class, no Firestore)
// rather than importing lib/features/dashboard/bulk_sync.dart, because that
// file pulls in package:cloud_firestore -> package:flutter -> dart:ui,
// which `dart run` can't load outside a Flutter target. The restriction
// logic here is copied verbatim from
// _BulkAddPageState._restrictToCreatesOnly.
//
// Run with: dart run tool/test_moderator_create_only.dart
class SheetDiff {
  SheetDiff({
    required this.collection,
    required this.label,
    required this.creates,
    required this.updates,
    required this.deletes,
  });

  final String collection;
  final String label;
  final List<Map<String, dynamic>> creates;
  final List<MapEntry<String, Map<String, dynamic>>> updates;
  final List<String> deletes;
}

class _RestrictedDiffs {
  _RestrictedDiffs(this.diffs, this.rejectedUpdates, this.rejectedDeletes);
  final List<SheetDiff> diffs;
  final int rejectedUpdates;
  final int rejectedDeletes;
}

_RestrictedDiffs _restrictToCreatesOnly(List<SheetDiff> diffs) {
  var rejectedUpdates = 0;
  var rejectedDeletes = 0;
  final restricted = <SheetDiff>[];
  for (final d in diffs) {
    rejectedUpdates += d.updates.length;
    rejectedDeletes += d.deletes.length;
    restricted.add(
      SheetDiff(
        collection: d.collection,
        label: d.label,
        creates: d.creates,
        updates: const [],
        deletes: const [],
      ),
    );
  }
  return _RestrictedDiffs(restricted, rejectedUpdates, rejectedDeletes);
}

void main() {
  // A diff shaped like what _diffDailyMessages would produce from a sheet
  // that has 2 new rows, 1 edited existing row, and 1 row marked for
  // deletion (docId kept, text cleared).
  final mixedDiff = SheetDiff(
    collection: 'dailyMessages',
    label: 'رسائل اليوم',
    creates: [
      {'hadithNumber': 1, 'arabic': 'رسالة جديدة ١'},
      {'hadithNumber': 1, 'arabic': 'رسالة جديدة ٢'},
    ],
    updates: [
      const MapEntry('doc1', {'arabic': 'نص مُعدَّل'}),
    ],
    deletes: ['doc2'],
  );

  print('Before restriction: creates=${mixedDiff.creates.length} '
      'updates=${mixedDiff.updates.length} deletes=${mixedDiff.deletes.length}');

  final result = _restrictToCreatesOnly([mixedDiff]);
  final restricted = result.diffs.single;

  print('After restriction:  creates=${restricted.creates.length} '
      'updates=${restricted.updates.length} deletes=${restricted.deletes.length} '
      '(rejectedUpdates=${result.rejectedUpdates}, '
      'rejectedDeletes=${result.rejectedDeletes})');

  final pass = restricted.creates.length == 2 &&
      restricted.updates.isEmpty &&
      restricted.deletes.isEmpty &&
      result.rejectedUpdates == 1 &&
      result.rejectedDeletes == 1 &&
      restricted.creates[0]['arabic'] == 'رسالة جديدة ١';

  print(pass
      ? 'PASS — creates survive untouched, updates and deletes are fully '
          'stripped. A moderator upload carrying edit/delete intent cannot '
          'reach Firestore with this diff.'
      : 'FAIL — the restriction did not behave as expected.');
}
