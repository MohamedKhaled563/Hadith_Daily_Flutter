import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin wrapper around Firestore's 500-write batch limit — every sheet sync
/// (immediate or admin-approved) stages into the same writer so one upload
/// commits as few batches as possible, auto-flushing just under the limit.
class BatchWriter {
  BatchWriter(this._db) : _batch = _db.batch();

  final FirebaseFirestore _db;
  WriteBatch _batch;
  int _pending = 0;

  /// How many writes have actually been committed so far (across every
  /// auto-flush at the 400-op mark, plus a final [flush]) — lets a caller
  /// report "N of M applied" if a later write in the same upload throws,
  /// since everything already committed here is permanent regardless.
  int committedCount = 0;

  Future<void> _maybeFlush() async {
    if (_pending >= 400) {
      await _batch.commit();
      committedCount += _pending;
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
    if (_pending > 0) {
      await _batch.commit();
      committedCount += _pending;
      _pending = 0;
    }
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

/// A Firestore `merge: true` set() creates the document if it's missing —
/// so if a doc this diff means to update was deleted (by another admin, or
/// because the uploaded sheet is stale) since the diff was built, applying
/// it as-is would silently resurrect a new doc under that id containing
/// only the columns this diff supplies, missing every other field a normal
/// doc in this collection has. Checked in batches of 30 (Firestore's
/// `whereIn` limit) rather than one read per doc.
Future<Set<String>> _existingDocIds(
  FirebaseFirestore db,
  String collection,
  List<String> ids,
) async {
  final existing = <String>{};
  for (var i = 0; i < ids.length; i += 30) {
    final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
    if (chunk.isEmpty) continue;
    final snapshot = await db
        .collection(collection)
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    existing.addAll(snapshot.docs.map((d) => d.id));
  }
  return existing;
}

/// Applies [diff] and returns the docIds among [SheetDiff.updates] that were
/// skipped because their target no longer exists — the caller should warn
/// the admin about these rather than let them pass silently.
Future<List<String>> applySheetDiff(
  FirebaseFirestore db,
  BatchWriter writer,
  SheetDiff diff,
) async {
  for (final docId in diff.deletes) {
    await writer.delete(db.collection(diff.collection).doc(docId));
  }

  final existingIds = await _existingDocIds(
    db,
    diff.collection,
    diff.updates.map((e) => e.key).toList(),
  );
  final skipped = <String>[];
  for (final entry in diff.updates) {
    if (!existingIds.contains(entry.key)) {
      skipped.add(entry.key);
      continue;
    }
    await writer.merge(db.collection(diff.collection).doc(entry.key), entry.value);
  }

  for (final fields in diff.creates) {
    final data = Map<String, dynamic>.from(fields);
    if (diff.addsServerTimestamp) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await writer.set(db.collection(diff.collection).doc(), data);
  }

  return skipped;
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
