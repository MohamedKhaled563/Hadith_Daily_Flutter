import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Two ways to bulk-edit dailyMessages, replacing the Google-Sheets-bridge
/// idea from the original roadmap — no separate sync tool, no spreadsheet
/// host, everything through the dashboard itself:
///
///  1. Quick paste — one hadith, many new lines, fastest for adding.
///  2. Excel round trip — download every dailyMessages row as .xlsx, edit
///     existing text or append new rows in Excel, upload it back. Rows
///     with a docId are updated in place; blank-docId rows are created.
///
/// Both the download and the upload go through package:file_picker's
/// saveFile()/pickFile(), which handle the browser download/upload dance
/// for us — no direct dart:html usage needed here.
class BulkAddPage extends StatefulWidget {
  const BulkAddPage({super.key});

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

  static const _headers = ['المعرف', 'رقم الحديث', 'النص', 'الترتيب'];

  Future<void> _downloadExcel() async {
    setState(() {
      _excelBusy = true;
      _excelResult = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('dailyMessages')
          .orderBy('order')
          .get();

      final workbook = xls.Excel.createExcel();
      final sheetName = workbook.getDefaultSheet()!;
      final sheet = workbook[sheetName];
      sheet.appendRow(_headers.map(xls.TextCellValue.new).toList());

      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          xls.TextCellValue(doc.id),
          xls.IntCellValue((data['hadithNumber'] as num?)?.toInt() ?? 0),
          xls.TextCellValue((data['arabic'] as String?) ?? ''),
          xls.IntCellValue((data['order'] as num?)?.toInt() ?? 0),
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
      await FilePicker.saveFile(
        fileName: 'daily-messages.xlsx',
        bytes: Uint8List.fromList(bytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult = 'تم تنزيل ${snapshot.docs.length} رسالة';
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
      final sheet = workbook.tables[workbook.tables.keys.first]!;
      final rows = sheet.rows.skip(1); // header

      final db = FirebaseFirestore.instance;
      final newRowsByHadith = <int, List<String>>{};
      final updates = <(String, int, String, int?)>[];

      for (final row in rows) {
        final docId = _cellString(row, 0);
        final hadithNumber = int.tryParse(_cellString(row, 1));
        final text = _cellString(row, 2).trim();
        final order = int.tryParse(_cellString(row, 3));
        if (hadithNumber == null || text.isEmpty) continue; // blank row

        if (docId.isEmpty) {
          newRowsByHadith.putIfAbsent(hadithNumber, () => []).add(text);
        } else {
          updates.add((docId, hadithNumber, text, order));
        }
      }

      var batch = db.batch();
      var pending = 0;
      Future<void> stage(
        DocumentReference<Map<String, dynamic>> ref,
        Map<String, dynamic> data, {
        bool merge = false,
      }) async {
        if (merge) {
          batch.set(ref, data, SetOptions(merge: true));
        } else {
          batch.set(ref, data);
        }
        pending++;
        if (pending >= 400) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }

      for (final (docId, hadithNumber, text, order) in updates) {
        await stage(db.collection('dailyMessages').doc(docId), {
          'hadithNumber': hadithNumber,
          'arabic': text,
          if (order != null) 'order': order,
        }, merge: true);
      }

      for (final entry in newRowsByHadith.entries) {
        final startSeq = await _countForHadith(db, entry.key);
        for (var i = 0; i < entry.value.length; i++) {
          await stage(db.collection('dailyMessages').doc(), {
            'hadithNumber': entry.key,
            'arabic': entry.value[i],
            'category': '',
            'order': entry.key * 100 + startSeq + i,
            'sourceWorkbook': 'dashboard-bulk-upload',
          });
        }
      }

      if (pending > 0) await batch.commit();

      if (!mounted) return;
      setState(() {
        _excelResultIsError = false;
        _excelResult =
            'تم تحديث ${updates.length} رسالة وإضافة '
            '${newRowsByHadith.values.fold(0, (n, l) => n + l.length)} رسالة جديدة';
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

  String _cellString(List<xls.Data?> row, int index) {
    if (index >= row.length) return '';
    return row[index]?.value?.toString() ?? '';
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
              'نزّل كل رسائل اليوم الحالية، عدّل النصوص أو أضف صفوفاً جديدة '
              '(اترك عمود "المعرف" فارغاً للصفوف الجديدة)، ثم ارفع الملف — '
              'الصفوف ذات المعرف تُحدَّث، والباقي يُضاف.',
            ),
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
              'إضافة سريعة (لصق)',
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
