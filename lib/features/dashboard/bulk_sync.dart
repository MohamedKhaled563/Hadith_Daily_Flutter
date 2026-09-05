import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin wrapper around Firestore's 500-write batch limit — every sheet sync
/// (immediate or admin-approved) stages into the same writer so one upload
/// commits as few batches as possible, auto-flushing just under the limit.
class BatchWriter {
  BatchWriter(this._db) : _batch = _db.batch();

  final FirebaseFirestore _db;
  WriteBatch _batch;
  int _pending = 0;

  Future<void> _maybeFlush() async {
    if (_pending >= 400) {
      await _batch.commit();
      _batch = _db.batch();
      _pending = 0;
    }
  }

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    _batch.set(ref, data);
    _pending++;
    await _maybeFlush();
  }

  Future<void> merge(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    _batch.set(ref, data, SetOptions(merge: true));
    _pending++;
    await _maybeFlush();
  }

  Future<void> delete(DocumentReference<Map<String, dynamic>> ref) async {
    _batch.delete(ref);
    _pending++;
    await _maybeFlush();
  }

  Future<void> flush() async {
    if (_pending > 0) await _batch.commit();
  }
}

/// The parsed, ready-to-write result of comparing one Excel sheet against
/// its Firestore collection. Fully serializable so a moderator's bulk edit
/// can be staged in `bulkChangeRequests` and applied later by an admin —
/// see [toJson]/[fromJson] and [BulkAddPage]/[BulkChangeRequestsPage].
class SheetDiff {
  SheetDiff({
    required this.collection,
    required this.label,
    required this.creates,
    required this.updates,
    required this.deletes,
    required this.invalidRows,
    this.addsServerTimestamp = false,
  });

  final String collection;
  final String label;
  final List<Map<String, dynamic>> creates;
  final List<MapEntry<String, Map<String, dynamic>>> updates;
  final List<String> deletes;
  final List<String> invalidRows;

  /// Whether [creates] need `createdAt: FieldValue.serverTimestamp()`
  /// stamped on at apply time — sentinels can't be stored inside a
  /// Firestore array, so this is applied in [applySheetDiff] instead of
  /// being baked into [creates] up front.
  final bool addsServerTimestamp;

  int get changeCount => creates.length + updates.length + deletes.length;

  Map<String, dynamic> toJson() => {
        'collection': collection,
        'label': label,
        'creates': creates,
        'updates': [
          for (final e in updates) {'docId': e.key, 'fields': e.value},
        ],
        'deletes': deletes,
        'invalidRowCount': invalidRows.length,
        'addsServerTimestamp': addsServerTimestamp,
      };

  factory SheetDiff.fromJson(Map<String, dynamic> json) => SheetDiff(
        collection: json['collection'] as String,
        label: json['label'] as String,
        creates: [
          for (final c in (json['creates'] as List? ?? const []))
            Map<String, dynamic>.from(c as Map),
        ],
        updates: [
          for (final u in (json['updates'] as List? ?? const []))
            MapEntry(
              (u as Map)['docId'] as String,
              Map<String, dynamic>.from(u['fields'] as Map),
            ),
        ],
        deletes: List<String>.from(json['deletes'] as List? ?? const []),
        invalidRows: const [],
        addsServerTimestamp: json['addsServerTimestamp'] as bool? ?? false,
      );
}

Future<void> applySheetDiff(
  FirebaseFirestore db,
  BatchWriter writer,
  SheetDiff diff,
) async {
  for (final docId in diff.deletes) {
    await writer.delete(db.collection(diff.collection).doc(docId));
  }
  for (final entry in diff.updates) {
    await writer.merge(db.collection(diff.collection).doc(entry.key), entry.value);
  }
  for (final fields in diff.creates) {
    final data = Map<String, dynamic>.from(fields);
    if (diff.addsServerTimestamp) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await writer.set(db.collection(diff.collection).doc(), data);
  }
}

String sheetDiffSummary(SheetDiff diff) {
  final buffer = StringBuffer(
    '${diff.label}: تحديث ${diff.updates.length}، حذف ${diff.deletes.length}، '
    'إضافة ${diff.creates.length}',
  );
  if (diff.invalidRows.isNotEmpty) {
    buffer.write(
      ' — تجاهل ${diff.invalidRows.length} صف: '
      '${diff.invalidRows.take(6).join('، ')}'
      '${diff.invalidRows.length > 6 ? '…' : ''}',
    );
  }
  return buffer.toString();
}

const kBulkChangeThreshold = 10;
