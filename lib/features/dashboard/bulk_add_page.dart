import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bulk_sync.dart';

/// Two ways to bulk-edit the three message collections, replacing the
/// Google-Sheets-bridge idea from the original roadmap — no separate sync
/// tool, no spreadsheet host, everything through the dashboard itself:
///
///  1. Quick paste — one hadith, many new lines, fastest for adding to
///     dailyMessages specifically.
///  2. Excel round trip — one workbook, three sheet tabs (one per
///     collection: dailyMessages, communityMessages, notificationMessages).
///     Edit existing text/status/order or append new rows in any sheet,
///     upload it back. Rows with a docId are updated in place; blank-docId
///     rows are created; clearing a row's text deletes that document.
///
/// Both the download and the upload go through package:file_picker's
/// saveFile()/pickFile(), which handle the browser download/upload dance
/// for us — no direct dart:html usage needed here.
///
/// A moderator's upload that touches more than [kBulkChangeThreshold] items
/// is staged in `bulkChangeRequests` instead of applied immediately — an
/// admin approves it from BulkChangeRequestsPage. Admins always apply at
/// once, since they'd otherwise have to approve their own edits.
class BulkAddPage extends StatefulWidget {
  const BulkAddPage({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<BulkAddPage> createState() => _BulkAddPageState();
}

class _BulkAddPageState extends State<BulkAddPage> {
  final _hadithController = TextEditingController();
  final _textController = TextEditingController();
  bool _pasteSubmitting = false;
  String? _pasteResult;
  bool _pasteResultIsError = false;

  bool _excelBusy = false;
  String? _excelResult;
  bool _excelResultIsError = false;

  @override
  void dispose() {
    _hadithController.dispose();
    _textController.dispose();
    super.dispose();
  }

  List<String> get _lines => _textController.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ---------------------------------------------------------------- paste ---

  Future<void> _submitPaste() async {
    final hadithNumber = int.tryParse(_hadithController.text.trim());
    final lines = _lines;

    if (hadithNumber == null || hadithNumber < 1 || hadithNumber > 42) {
      setState(() {
        _pasteResultIsError = true;
        _pasteResult = 'أدخل رقم حديث صحيح بين ١ و ٤٢';
      });
      return;
    }
    if (lines.isEmpty) {
      setState(() {
        _pasteResultIsError = true;
        _pasteResult = 'أضف سطراً واحداً على الأقل';
      });
      return;
    }

    setState(() {
      _pasteSubmitting = true;
      _pasteResult = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final startSeq = await _countForHadith(db, hadithNumber);

      final batch = db.batch();
      for (var i = 0; i < lines.length; i++) {
        final ref = db.collection('dailyMessages').doc();
        batch.set(ref, {
          'hadithNumber': hadithNumber,
          'arabic': lines[i],
          'category': '',
          'order': hadithNumber * 100 + startSeq + i,
          'sourceWorkbook': 'dashboard-bulk-add',
        });
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _pasteResultIsError = false;
        _pasteResult = 'تمت إضافة ${lines.length} رسالة للحديث $hadithNumber بنجاح';
        _textController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pasteResultIsError = true;
        _pasteResult = 'تعذّرت الإضافة: $e';
      });
    } finally {
      if (mounted) setState(() => _pasteSubmitting = false);
    }
  }

  Future<int> _countForHadith(FirebaseFirestore db, int hadithNumber) async {
    final agg = await db
        .collection('dailyMessages')
        .where('hadithNumber', isEqualTo: hadithNumber)
        .count()
        .get();
    return agg.count ?? 0;
  }

  // --------------------------------------------------------------- excel ---

  static const _dailySheet = 'رسائل اليوم';
  static const _communitySheet = 'مجتمع الحديث';
  static const _notificationSheet = 'رسائل التنبيه';

  static const _dailyHeaders = ['المعرف', 'رقم الحديث', 'النص', 'الترتيب'];
  static const _communityHeaders = [
    'المعرف',
    'رقم الحديث',
    'النص',
    'الحالة',
    'الإعجابات',
    'اسم الكاتب',
    'معرف الكاتب',
    'تاريخ الإضافة',
    'الترتيب',
  ];
  static const _notificationHeaders = ['المعرف', 'النص', 'نشطة', 'الترتيب'];

  static const _statusLabels = {
    'pending': 'قيد المراجعة',
    'approved': 'معتمدة',
    'rejected': 'مرفوضة',
  };
  static const _statusFromLabel = {
    'قيد المراجعة': 'pending',
    'معتمدة': 'approved',
    'مرفوضة': 'rejected',
  };

  Future<void> _downloadExcel() async {
    setState(() {
      _excelBusy = true;
      _excelResult = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final workbook = xls.Excel.createExcel();

      final dailySnap =
          await db.collection('dailyMessages').orderBy('order').get();
      final dailySheet = workbook[_dailySheet];
      dailySheet.appendRow(_dailyHeaders.map(xls.TextCellValue.new).toList());
      for (final doc in dailySnap.docs) {
        final data = doc.data();
        dailySheet.appendRow([
          xls.TextCellValue(doc.id),
          xls.IntCellValue((data['hadithNumber'] as num?)?.toInt() ?? 0),
          xls.TextCellValue((data['arabic'] as String?) ?? ''),
          xls.IntCellValue((data['order'] as num?)?.toInt() ?? 0),
        ]);
      }

      final communitySnap = await db
          .collection('communityMessages')
          .orderBy('createdAt')
          .get();
      final communitySheet = workbook[_communitySheet];
      communitySheet
          .appendRow(_communityHeaders.map(xls.TextCellValue.new).toList());
      for (final doc in communitySnap.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        communitySheet.appendRow([
          xls.TextCellValue(doc.id),
          xls.IntCellValue((data['hadithNumber'] as num?)?.toInt() ?? 0),
          xls.TextCellValue((data['message'] as String?) ?? ''),
          xls.TextCellValue(
            _statusLabels[data['status'] as String?] ?? 'قيد المراجعة',
          ),
          xls.IntCellValue((data['likeCount'] as num?)?.toInt() ?? 0),
          xls.TextCellValue((data['authorName'] as String?) ?? ''),
          xls.TextCellValue((data['authorUid'] as String?) ?? ''),
          xls.TextCellValue(
            createdAt is Timestamp ? _formatTimestamp(createdAt) : '',
          ),
          xls.IntCellValue((data['order'] as num?)?.toInt() ?? 0),
        ]);
      }

      final notificationSnap =
          await db.collection('notificationMessages').orderBy('order').get();
      final notificationSheet = workbook[_notificationSheet];
      notificationSheet
          .appendRow(_notificationHeaders.map(xls.TextCellValue.new).toList());
      for (final doc in notificationSnap.docs) {
        final data = doc.data();
        notificationSheet.appendRow([
          xls.TextCellValue(doc.id),
          xls.TextCellValue((data['text'] as String?) ?? ''),
          xls.TextCellValue((data['active'] as bool? ?? true) ? 'نعم' : 'لا'),
          xls.IntCellValue((data['order'] as num?)?.toInt() ?? 0),
        ]);
      }

      // excel's createExcel() ships a "Sheet1" placeholder — drop it once
      // the three real sheets above exist, otherwise it opens as an extra
      // blank tab in the workbook.
      if (workbook.sheets.containsKey('Sheet1')) {
        workbook.delete('Sheet1');
      }

      final bytes = workbook.encode();
      if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
      await FilePicker.saveFile(
        fileName: 'hadith-messages.xlsx',
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult = 'تم تنزيل ${dailySnap.docs.length} رسالة يومية، '
            '${communitySnap.docs.length} مشاركة مجتمع، '
            '${notificationSnap.docs.length} رسالة تنبيه';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _excelResultIsError = true;
        _excelResult = 'تعذّر التنزيل: $e';
      });
    } finally {
      if (mounted) setState(() => _excelBusy = false);
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _uploadExcel() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (file == null) return; // cancelled
    final bytes = await file.readAsBytes();

    setState(() {
      _excelBusy = true;
      _excelResult = null;
    });

    try {
      final workbook = xls.Excel.decodeBytes(bytes);
      final db = FirebaseFirestore.instance;
      final diffs = <SheetDiff>[];

      if (workbook.tables.containsKey(_dailySheet)) {
        diffs.add(await _diffDailyMessages(db, workbook.tables[_dailySheet]!));
      }
      if (workbook.tables.containsKey(_communitySheet)) {
        diffs.add(
          await _diffCommunityMessages(db, workbook.tables[_communitySheet]!),
        );
      }
      if (workbook.tables.containsKey(_notificationSheet)) {
        diffs.add(
          await _diffNotificationMessages(
            db,
            workbook.tables[_notificationSheet]!,
          ),
        );
      }

      final totalChanges = diffs.fold(0, (n, d) => n + d.changeCount);

      // A moderator's large bulk edit needs an admin's sign-off first —
      // stage it instead of writing directly. Admins always apply at once,
      // regardless of size, since they're the ones who'd otherwise have to
      // approve their own change.
      if (!widget.isAdmin && totalChanges > kBulkChangeThreshold) {
        final user = FirebaseAuth.instance.currentUser;
        await db.collection('bulkChangeRequests').add({
          'status': 'pending',
          'submittedByUid': user?.uid ?? '',
          'submittedByEmail': user?.email ?? '',
          'submittedAt': FieldValue.serverTimestamp(),
          'totalChanges': totalChanges,
          'sheets': {for (final d in diffs) d.collection: d.toJson()},
        });

        if (!mounted) return;
        setState(() {
          _excelResultIsError = false;
          _excelResult = 'هذا التعديل يشمل $totalChanges عنصراً (أكثر من '
              '$kBulkChangeThreshold) فتم إرساله لمراجعة المدير قبل التنفيذ '
              '— راجع تبويب "طلبات المراجعة" لمتابعة حالته.';
        });
        return;
      }

      final totalDeletes = diffs.fold(0, (n, d) => n + d.deletes.length);
      if (totalDeletes > 0) {
        if (!mounted) return;
        final confirmed = await _confirmDeletes(diffs);
        if (!confirmed) {
          if (!mounted) return;
          setState(() {
            _excelResultIsError = false;
            _excelResult = 'أُلغي الرفع — لم يُحذف أو يُحدَّث أي شيء.';
          });
          return;
        }
      }

      final writer = BatchWriter(db);
      for (final diff in diffs) {
        await applySheetDiff(db, writer, diff);
      }
      await writer.flush();

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult = diffs.map(sheetDiffSummary).join('\n');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _excelResultIsError = true;
        _excelResult = 'تعذّر الرفع: $e';
      });
    } finally {
      if (mounted) setState(() => _excelBusy = false);
    }
  }

  /// Shows exactly which documents are about to be deleted (by collection
  /// and docId) and requires an explicit confirmation before the upload
  /// proceeds — a moderator or admin should never lose content to a
  /// spreadsheet edit they didn't intend as a deletion.
  Future<bool> _confirmDeletes(List<SheetDiff> diffs) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final diff in diffs.where((d) => d.deletes.isNotEmpty)) ...[
                Text(
                  '${diff.label}: سيُحذف ${diff.deletes.length} عنصراً نهائياً',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  diff.deletes.take(10).join('، ') +
                      (diff.deletes.length > 10 ? '…' : ''),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              const Text('هل تريد المتابعة؟'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // -------------------------------------------------------- dailyMessages ---

  Future<SheetDiff> _diffDailyMessages(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'dailyMessages';
    final rows = sheet.rows.skip(1);

    final newRowsByHadith = <int, List<String>>{};
    final updates = <MapEntry<String, Map<String, dynamic>>>[];
    final deletes = <String>{};
    final invalidRows = <String>[];
    final seenDocIds = <String>{};

    var rowNumber = 1;
    for (final row in rows) {
      rowNumber++;
      final docId = _cellString(row, 0);
      final hadithNumberRaw = _cellString(row, 1);
      final text = _cellString(row, 2).trim();
      final orderRaw = _cellString(row, 3);

      if (docId.isEmpty && hadithNumberRaw.isEmpty && text.isEmpty) continue;

      if (docId.isNotEmpty && !seenDocIds.add(docId)) {
        invalidRows.add('$rowNumber (معرف مكرر)');
        continue;
      }

      if (docId.isNotEmpty && text.isEmpty) {
        deletes.add(docId);
        continue;
      }

      final hadithNumber = int.tryParse(_normalizeDigits(hadithNumberRaw));
      if (hadithNumber == null || hadithNumber < 1 || hadithNumber > 42) {
        invalidRows.add('$rowNumber (رقم حديث غير صحيح)');
        continue;
      }
      if (text.isEmpty) {
        invalidRows.add('$rowNumber (نص فارغ)');
        continue;
      }
      final order =
          orderRaw.isEmpty ? null : int.tryParse(_normalizeDigits(orderRaw));

      if (docId.isEmpty) {
        newRowsByHadith.putIfAbsent(hadithNumber, () => []).add(text);
      } else {
        updates.add(MapEntry(docId, {
          'hadithNumber': hadithNumber,
          'arabic': text,
          if (order != null) 'order': order,
        }));
      }
    }

    final existingDocs = {
      for (final d in (await db.collection(collection).get(
            const GetOptions(source: Source.server),
          ))
              .docs)
        d.id: d.data(),
    };
    // Deletes are explicit only: a docId present with a blank "text" cell.
    // A row simply missing from the sheet (filtered out, sorted away, or
    // never downloaded because it was created after the last download)
    // must NOT be treated as a delete request — see the bulk-editor
    // deletion-safety fix.
    updates.removeWhere((e) => _unchanged(e.value, existingDocs[e.key]));

    final creates = <Map<String, dynamic>>[];
    for (final entry in newRowsByHadith.entries) {
      final startSeq = await _countForHadith(db, entry.key);
      for (var i = 0; i < entry.value.length; i++) {
        creates.add({
          'hadithNumber': entry.key,
          'arabic': entry.value[i],
          'category': '',
          'order': entry.key * 100 + startSeq + i,
          'sourceWorkbook': 'dashboard-bulk-upload',
        });
      }
    }

    return SheetDiff(
      collection: collection,
      label: 'رسائل اليوم',
      creates: creates,
      updates: updates,
      deletes: deletes.toList(),
      invalidRows: invalidRows,
    );
  }

  // ---------------------------------------------------- communityMessages ---

  Future<SheetDiff> _diffCommunityMessages(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'communityMessages';
    final rows = sheet.rows.skip(1);
    final currentUser = FirebaseAuth.instance.currentUser;

    final creates = <Map<String, dynamic>>[];
    final updates = <MapEntry<String, Map<String, dynamic>>>[];
    final deletes = <String>{};
    final invalidRows = <String>[];
    final seenDocIds = <String>{};

    var rowNumber = 1;
    for (final row in rows) {
      rowNumber++;
      final docId = _cellString(row, 0);
      final hadithNumberRaw = _cellString(row, 1);
      final text = _cellString(row, 2).trim();
      final statusLabel = _cellString(row, 3).trim();
      final likesRaw = _cellString(row, 4);
      final authorName = _cellString(row, 5).trim();
      final orderRaw = _cellString(row, 8);

      if (docId.isEmpty && hadithNumberRaw.isEmpty && text.isEmpty) continue;

      if (docId.isNotEmpty && !seenDocIds.add(docId)) {
        invalidRows.add('$rowNumber (معرف مكرر)');
        continue;
      }

      if (docId.isNotEmpty && text.isEmpty) {
        deletes.add(docId);
        continue;
      }

      final hadithNumber = int.tryParse(_normalizeDigits(hadithNumberRaw));
      if (hadithNumber == null || hadithNumber < 1 || hadithNumber > 42) {
        invalidRows.add('$rowNumber (رقم حديث غير صحيح)');
        continue;
      }
      if (text.isEmpty) {
        invalidRows.add('$rowNumber (نص فارغ)');
        continue;
      }
      if (text.length > 2000) {
        invalidRows.add('$rowNumber (النص أطول من ٢٠٠٠ حرف)');
        continue;
      }

      final isNew = docId.isEmpty;
      final status = _statusFromLabel[statusLabel] ??
          (isNew && statusLabel.isEmpty ? 'approved' : null);
      if (status == null) {
        invalidRows.add(
          '$rowNumber (حالة غير معروفة — استخدم قيد المراجعة/معتمدة/مرفوضة)',
        );
        continue;
      }

      final order =
          orderRaw.isEmpty ? null : int.tryParse(_normalizeDigits(orderRaw));

      if (isNew) {
        creates.add({
          'authorUid': currentUser?.uid ?? '',
          'authorName': authorName.isEmpty ? 'لوحة الإشراف' : authorName,
          'hadithNumber': hadithNumber,
          'message': text,
          'status': status,
          'likeCount': 0,
          if (order != null) 'order': order,
        });
      } else {
        final likes = likesRaw.isEmpty
            ? null
            : int.tryParse(_normalizeDigits(likesRaw));
        updates.add(MapEntry(docId, {
          'hadithNumber': hadithNumber,
          'message': text,
          'status': status,
          if (authorName.isNotEmpty) 'authorName': authorName,
          if (likes != null) 'likeCount': likes,
          if (order != null) 'order': order,
        }));
      }
    }

    final existingDocs = {
      for (final d in (await db.collection(collection).get(
            const GetOptions(source: Source.server),
          ))
              .docs)
        d.id: d.data(),
    };
    // Deletes are explicit only — see the matching comment in
    // _diffDailyMessages.
    updates.removeWhere((e) => _unchanged(e.value, existingDocs[e.key]));

    return SheetDiff(
      collection: collection,
      label: 'مجتمع الحديث',
      creates: creates,
      updates: updates,
      deletes: deletes.toList(),
      invalidRows: invalidRows,
      addsServerTimestamp: true,
    );
  }

  // ------------------------------------------------- notificationMessages ---

  Future<SheetDiff> _diffNotificationMessages(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'notificationMessages';
    final rows = sheet.rows.skip(1);

    final creates = <Map<String, dynamic>>[];
    final updates = <MapEntry<String, Map<String, dynamic>>>[];
    final deletes = <String>{};
    final invalidRows = <String>[];
    final seenDocIds = <String>{};

    var rowNumber = 1;
    var newSeq = await _countForCollection(db, collection);
    for (final row in rows) {
      rowNumber++;
      final docId = _cellString(row, 0);
      final text = _cellString(row, 1).trim();
      final activeRaw = _cellString(row, 2).trim();
      final orderRaw = _cellString(row, 3);

      if (docId.isEmpty && text.isEmpty) continue;

      if (docId.isNotEmpty && !seenDocIds.add(docId)) {
        invalidRows.add('$rowNumber (معرف مكرر)');
        continue;
      }

      if (docId.isNotEmpty && text.isEmpty) {
        deletes.add(docId);
        continue;
      }

      if (text.isEmpty) {
        invalidRows.add('$rowNumber (نص فارغ)');
        continue;
      }
      if (text.length > 300) {
        invalidRows.add('$rowNumber (النص أطول من ٣٠٠ حرف)');
        continue;
      }

      bool? active;
      if (activeRaw.isNotEmpty) {
        if (activeRaw == 'نعم') {
          active = true;
        } else if (activeRaw == 'لا') {
          active = false;
        } else {
          invalidRows.add('$rowNumber (عمود نشطة يجب أن يكون نعم أو لا)');
          continue;
        }
      }

      final order =
          orderRaw.isEmpty ? null : int.tryParse(_normalizeDigits(orderRaw));

      if (docId.isEmpty) {
        creates.add({
          'text': text,
          'active': active ?? true,
          'order': order ?? newSeq,
        });
        newSeq++;
      } else {
        updates.add(MapEntry(docId, {
          'text': text,
          if (active != null) 'active': active,
          if (order != null) 'order': order,
        }));
      }
    }

    final existingDocs = {
      for (final d in (await db.collection(collection).get(
            const GetOptions(source: Source.server),
          ))
              .docs)
        d.id: d.data(),
    };
    // Deletes are explicit only — see the matching comment in
    // _diffDailyMessages.
    updates.removeWhere((e) => _unchanged(e.value, existingDocs[e.key]));

    return SheetDiff(
      collection: collection,
      label: 'رسائل التنبيه',
      creates: creates,
      updates: updates,
      deletes: deletes.toList(),
      invalidRows: invalidRows,
      addsServerTimestamp: true,
    );
  }

  /// True when every field the upload would write already matches what's
  /// in Firestore — lets a no-op download→upload round trip report "0
  /// updated" instead of rewriting every row with identical data.
  bool _unchanged(Map<String, dynamic> newFields, Map<String, dynamic>? existing) {
    if (existing == null) return false;
    for (final entry in newFields.entries) {
      if (existing[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<int> _countForCollection(FirebaseFirestore db, String collection) async {
    final agg = await db.collection(collection).count().get();
    return agg.count ?? 0;
  }

  String _cellString(List<xls.Data?> row, int index) {
    if (index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  static const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// Excel round trips through Arabic locales sometimes leave numeric cells
  /// as Arabic-Indic digits (٠-٩) instead of ASCII ones — int.tryParse
  /// doesn't understand those, so normalize before parsing.
  String _normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final ch in input.codeUnits) {
      final index = _arabicIndicDigits.codeUnits.indexOf(ch);
      buffer.writeCharCode(index == -1 ? ch : 0x30 + index);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تنزيل ورفع Excel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'ملف واحد بثلاث أوراق (تبويبات): "رسائل اليوم"، "مجتمع الحديث"، '
              '"رسائل التنبيه". عدّل النصوص أو أضف صفوفاً جديدة (اترك عمود '
              '"المعرف" فارغاً للصفوف الجديدة) في أي ورقة، ثم ارفع الملف — '
              'الصفوف ذات المعرف تُحدَّث، والجديدة تُضاف. لحذف رسالة، أبقِ '
              'عمود "المعرف" كما هو وامسح عمود "النص" فقط. في ورقة "مجتمع '
              'الحديث"، عمود "الحالة" يقبل: قيد المراجعة / معتمدة / مرفوضة — '
              'وتغييره هو نفسه إجراء الاعتماد أو الرفض.',
            ),
            if (!widget.isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'ملاحظة: أي رفعة تشمل أكثر من $kBulkChangeThreshold عناصر '
                '(تحديث + حذف + إضافة) تُرسَل لمراجعة المدير قبل التنفيذ، '
                'ولا تُطبَّق مباشرة.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _excelBusy ? null : _downloadExcel,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('تنزيل Excel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _excelBusy ? null : _uploadExcel,
                    icon: _excelBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: const Text('رفع Excel'),
                  ),
                ),
              ],
            ),
            if (_excelResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _excelResult!,
                style: TextStyle(
                  color: _excelResultIsError ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'إضافة سريعة (لصق) — رسائل اليوم فقط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'لإضافة رسائل جديدة لحديث واحد بسرعة، دون المرور بملف Excel.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _hadithController,
                keyboardType: TextInputType.number,
                enabled: !_pasteSubmitting,
                decoration: const InputDecoration(
                  labelText: 'رقم الحديث (١-٤٢)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 5,
              enabled: !_pasteSubmitting,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'الرسائل — سطر لكل رسالة',
                border: const OutlineInputBorder(),
                helperText: '${_lines.length} رسالة جاهزة للإضافة',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_pasteResult != null) ...[
              Text(
                _pasteResult!,
                style: TextStyle(
                  color: _pasteResultIsError ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _pasteSubmitting ? null : _submitPaste,
              icon: _pasteSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_rounded),
              label: Text(_pasteSubmitting ? 'جارٍ الإضافة…' : 'إضافة الرسائل'),
            ),
          ],
        ),
      ),
    );
  }
}
