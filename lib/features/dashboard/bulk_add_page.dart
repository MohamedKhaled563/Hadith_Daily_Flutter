import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bulk_add_parsing.dart' as parsing;
import 'bulk_sync.dart';

/// Two ways to bulk-add to the three message collections, replacing the
/// Google-Sheets-bridge idea from the original roadmap — no separate sync
/// tool, no spreadsheet host, everything through the dashboard itself:
///
///  1. Quick paste — one hadith, many new lines, fastest for adding to
///     dailyMessages specifically. Always create-only, for both roles.
///  2. Excel round trip — one workbook, three sheet tabs (one per
///     collection: dailyMessages, communityMessages, notificationMessages).
///
/// The Excel round trip is **add-only for every role** — a moderator and an
/// admin get the exact same upload template and the exact same behavior:
/// every row in the sheet becomes a new document. There is no "المعرف"
/// (docId) column anywhere in the upload template, so there is nothing for
/// either role to type an id into, nothing to key an update or a delete
/// off of, and nothing that can accidentally overwrite or delete an
/// existing message. Editing or deleting an existing message happens
/// per-item elsewhere in the dashboard (e.g. "رسائل التنبيه" or the pending
/// review queue), never through this Excel tool.
///
/// Only an admin can additionally download the *current* data (every
/// existing row, with its docId) — purely to see what already exists
/// (e.g. to avoid duplicating a hadith, or to check current order values).
/// That export is read-only in spirit: re-uploading it verbatim would just
/// create a duplicate of every row it contains, since the upload path has
/// no way to recognize a docId column even if one is present. Uploading it
/// is explicitly guarded against — see [parsing.headerMismatchNote].
///
/// Both the download and the upload go through package:file_picker's
/// saveFile()/pickFile(), which handle the browser download/upload dance
/// for us — no direct dart:html usage needed here.
///
/// An upload that adds more than [kBulkChangeThreshold] items from a
/// moderator is still staged in `bulkChangeRequests` instead of applied
/// immediately — an admin approves it from BulkChangeRequestsPage. Admins
/// always apply at once, since they'd otherwise have to approve their own
/// additions.
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

  /// Headers for the admin-only, read-only "current data" export — the
  /// only place "المعرف" (docId) ever appears in this feature.
  static const _dailyViewHeaders = ['المعرف', 'رقم الحديث', 'النص', 'الترتيب'];
  static const _communityViewHeaders = [
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
  static const _notificationViewHeaders = ['المعرف', 'النص', 'نشطة', 'الترتيب'];

  static const _statusLabels = {
    'pending': 'قيد المراجعة',
    'approved': 'معتمدة',
    'rejected': 'مرفوضة',
  };

  /// Admin-only: every existing row across the three collections, with its
  /// docId, for reference — never meant to be re-uploaded. See the class
  /// doc comment and [parsing.headerMismatchNote].
  Future<void> _downloadCurrentData() async {
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
      dailySheet
          .appendRow(_dailyViewHeaders.map(xls.TextCellValue.new).toList());
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
      communitySheet.appendRow(
        _communityViewHeaders.map(xls.TextCellValue.new).toList(),
      );
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
      notificationSheet.appendRow(
        _notificationViewHeaders.map(xls.TextCellValue.new).toList(),
      );
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
        fileName: 'hadith-messages-current-data.xlsx',
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult = 'تم تنزيل ${dailySnap.docs.length} رسالة يومية، '
            '${communitySnap.docs.length} مشاركة مجتمع، '
            '${notificationSnap.docs.length} رسالة تنبيه — '
            'هذا الملف للعرض فقط، لا تُعِد رفعه؛ لإضافة رسائل جديدة استخدم '
            '"تنزيل نموذج الإضافة".';
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

  /// The add-only upload template: the same three sheet tabs both roles
  /// upload, with no docId column and no existing data — there is nothing
  /// here that could leak or overwrite current content because there's
  /// nothing of the current data in the file to begin with.
  Future<void> _downloadTemplate() async {
    setState(() {
      _excelBusy = true;
      _excelResult = null;
    });

    try {
      final workbook = xls.Excel.createExcel();
      workbook[_dailySheet].appendRow(
        parsing.dailyAddHeaders.map(xls.TextCellValue.new).toList(),
      );
      workbook[_communitySheet].appendRow(
        parsing.communityAddHeaders.map(xls.TextCellValue.new).toList(),
      );
      workbook[_notificationSheet].appendRow(
        parsing.notificationAddHeaders.map(xls.TextCellValue.new).toList(),
      );

      if (workbook.sheets.containsKey('Sheet1')) {
        workbook.delete('Sheet1');
      }

      final bytes = workbook.encode();
      if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
      await FilePicker.saveFile(
        fileName: 'hadith-messages-add-template.xlsx',
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult = 'تم تنزيل نموذج فارغ. أضف صفوف الرسائل الجديدة في أي '
            'ورقة ثم ارفعه — كل صف يصبح رسالة جديدة.';
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

    BatchWriter? writer;
    try {
      final workbook = xls.Excel.decodeBytes(bytes);
      final db = FirebaseFirestore.instance;
      final diffs = <SheetDiff>[];

      if (workbook.tables.containsKey(_dailySheet)) {
        diffs.add(
          await _collectDailyCreates(db, workbook.tables[_dailySheet]!),
        );
      }
      if (workbook.tables.containsKey(_communitySheet)) {
        diffs.add(
          await _collectCommunityCreates(
            db,
            workbook.tables[_communitySheet]!,
          ),
        );
      }
      if (workbook.tables.containsKey(_notificationSheet)) {
        diffs.add(
          await _collectNotificationCreates(
            db,
            workbook.tables[_notificationSheet]!,
          ),
        );
      }

      final totalChanges = diffs.fold(0, (n, d) => n + d.changeCount);

      // A moderator's large bulk add needs an admin's sign-off first —
      // stage it instead of writing directly. Admins always apply at once,
      // regardless of size, since they're the ones who'd otherwise have to
      // approve their own additions.
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
          _excelResult = 'هذه الإضافة تشمل $totalChanges عنصراً (أكثر من '
              '$kBulkChangeThreshold) فتم إرسالها لمراجعة المدير قبل التنفيذ '
              '— راجع تبويب "طلبات المراجعة" لمتابعة حالتها.';
        });
        return;
      }

      writer = BatchWriter(db);
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
        _excelResult =
            'تعذّر الرفع بعد تطبيق ${writer?.committedCount ?? 0} تغيير: $e';
      });
    } finally {
      if (mounted) setState(() => _excelBusy = false);
    }
  }

  // -------------------------------------------------------- dailyMessages ---

  /// Add-only: every valid row becomes a new dailyMessages doc. There is no
  /// docId column any more, so there is nothing here that can update or
  /// delete an existing message — see the class doc comment. Row parsing
  /// and validation live in bulk_add_parsing.dart (pure, directly unit
  /// tested by tool/test_bulk_add_parsing.dart); only the per-hadith
  /// starting sequence number needs Firestore, so that part stays here.
  Future<SheetDiff> _collectDailyCreates(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'dailyMessages';
    const label = 'رسائل اليوم';

    final headerError = parsing.headerMismatchNote(sheet, parsing.dailyAddHeaders);
    if (headerError != null) {
      return SheetDiff(
        collection: collection,
        label: label,
        creates: const [],
        updates: const [],
        deletes: const [],
        invalidRows: [headerError],
      );
    }

    final parsed = parsing.parseDailyRows(sheet);

    final creates = <Map<String, dynamic>>[];
    for (final entry in parsed.newRowsByHadith.entries) {
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
      label: label,
      creates: creates,
      updates: const [],
      deletes: const [],
      invalidRows: parsed.invalidRows,
    );
  }

  // ---------------------------------------------------- communityMessages ---

  /// Add-only, same as [_collectDailyCreates]. A dashboard-authored
  /// community message is created straight into 'approved' status — if it
  /// needs review first, that's what the ordinary author-submits-pending
  /// path and the pending-queue tab are for. Fully pure aside from
  /// stamping the current admin/moderator's uid, so parsing lives entirely
  /// in bulk_add_parsing.dart.
  Future<SheetDiff> _collectCommunityCreates(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'communityMessages';
    const label = 'مجتمع الحديث';

    final headerError =
        parsing.headerMismatchNote(sheet, parsing.communityAddHeaders);
    if (headerError != null) {
      return SheetDiff(
        collection: collection,
        label: label,
        creates: const [],
        updates: const [],
        deletes: const [],
        invalidRows: [headerError],
        addsServerTimestamp: true,
      );
    }

    final parsed = parsing.parseCommunityRows(sheet);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final creates = [
      for (final fields in parsed.creates) {...fields, 'authorUid': currentUid},
    ];

    return SheetDiff(
      collection: collection,
      label: label,
      creates: creates,
      updates: const [],
      deletes: const [],
      invalidRows: parsed.invalidRows,
      addsServerTimestamp: true,
    );
  }

  // ------------------------------------------------- notificationMessages ---

  /// Add-only, same as [_collectDailyCreates]. Only the starting sequence
  /// number for rows with no explicit "الترتيب" needs Firestore.
  Future<SheetDiff> _collectNotificationCreates(
    FirebaseFirestore db,
    xls.Sheet sheet,
  ) async {
    const collection = 'notificationMessages';
    const label = 'رسائل التنبيه';

    final headerError =
        parsing.headerMismatchNote(sheet, parsing.notificationAddHeaders);
    if (headerError != null) {
      return SheetDiff(
        collection: collection,
        label: label,
        creates: const [],
        updates: const [],
        deletes: const [],
        invalidRows: [headerError],
        addsServerTimestamp: true,
      );
    }

    final startSeq = await _countForCollection(db, collection);
    final parsed = parsing.parseNotificationRows(sheet, startSeq: startSeq);

    return SheetDiff(
      collection: collection,
      label: label,
      creates: parsed.creates,
      updates: const [],
      deletes: const [],
      invalidRows: parsed.invalidRows,
      addsServerTimestamp: true,
    );
  }

  Future<int> _countForCollection(FirebaseFirestore db, String collection) async {
    final agg = await db.collection(collection).count().get();
    return agg.count ?? 0;
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
              'إضافة عبر Excel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'نزّل نموذج الإضافة (ثلاث أوراق: "رسائل اليوم"، "مجتمع الحديث"، '
              '"رسائل التنبيه")، أضف صفوف الرسائل الجديدة فيه، ثم ارفعه — كل '
              'صف يصبح رسالة جديدة. هذه الأداة للإضافة فقط: لا يمكنك من '
              'خلالها تعديل أو حذف رسالة موجودة.',
            ),
            const SizedBox(height: 8),
            Text(
              'ملاحظة: أي رفعة تضيف أكثر من $kBulkChangeThreshold عناصر من '
              'مشرف تُرسَل لمراجعة المدير قبل التنفيذ، ولا تُطبَّق مباشرة.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _excelBusy ? null : _downloadTemplate,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('تنزيل نموذج الإضافة'),
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
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _excelBusy ? null : _downloadCurrentData,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('تنزيل البيانات الحالية (للعرض فقط)'),
              ),
              const SizedBox(height: 4),
              Text(
                'ملف مرجعي فقط لرؤية كل الرسائل الموجودة حالياً بمعرّفاتها — '
                'لا ترفعه مرة أخرى، فسيُضيف كل صف فيه كرسالة مكررة جديدة.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
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
