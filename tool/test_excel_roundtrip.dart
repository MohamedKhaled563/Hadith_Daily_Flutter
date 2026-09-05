// Standalone diagnostic for the "added row not detected" bug reported
// against lib/features/dashboard/bulk_add_page.dart. Builds a workbook the
// same way _downloadExcel does, round-trips it through encode/decode twice
// (simulating: app downloads -> user opens & re-saves in a spreadsheet app
// -> user uploads), appending one new row in between, then re-runs the same
// row-reading logic the dashboard uses to see whether the appended row
// survives and parses correctly.
//
// Run with: dart run tool/test_excel_roundtrip.dart
import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;

const _headers = ['المعرف', 'رقم الحديث', 'النص', 'الترتيب'];

String cellString(List<xls.Data?> row, int index) {
  if (index >= row.length) return '';
  return row[index]?.value?.toString().trim() ?? '';
}

void main() {
  // Step 1: build like _downloadExcel does — 3 pre-existing rows with docIds.
  final workbook = xls.Excel.createExcel();
  final sheet = workbook['رسائل اليوم'];
  sheet.appendRow(_headers.map(xls.TextCellValue.new).toList());
  for (var i = 1; i <= 3; i++) {
    sheet.appendRow([
      xls.TextCellValue('doc$i'),
      xls.IntCellValue(1),
      xls.TextCellValue('نص تجريبي رقم $i'),
      xls.IntCellValue(100 + i),
    ]);
  }
  if (workbook.sheets.containsKey('Sheet1')) workbook.delete('Sheet1');

  var bytes = workbook.encode()!;
  print('Step 1: built ${bytes.length} bytes, 3 existing rows + header.');

  // Step 2: simulate "user downloads it, opens it, appends one new row
  // leaving المعرف blank, then saves" — decode, mutate, re-encode.
  var reopened = xls.Excel.decodeBytes(Uint8List.fromList(bytes));
  var reopenedSheet = reopened.tables['رسائل اليوم']!;
  print('Step 2: reopened sheet has ${reopenedSheet.maxRows} rows '
      '(expected 4: header + 3).');

  reopenedSheet.appendRow([
    xls.TextCellValue(''), // blank docId — this row should be "new"
    xls.IntCellValue(7),
    xls.TextCellValue('رسالة جديدة أضافها المستخدم'),
    xls.TextCellValue(''), // order left blank
  ]);
  print('Step 3: after appendRow, in-memory sheet has '
      '${reopenedSheet.maxRows} rows (expected 5).');

  bytes = reopened.encode()!;
  print('Step 4: re-encoded to ${bytes.length} bytes.');

  // Step 3: simulate the dashboard's _uploadExcel — decode fresh and run
  // exactly the same row-reading loop bulk_add_page.dart uses.
  final uploaded = xls.Excel.decodeBytes(Uint8List.fromList(bytes));
  final uploadedSheet = uploaded.tables['رسائل اليوم']!;
  print('Step 5: freshly decoded upload sheet has '
      '${uploadedSheet.maxRows} rows (expected 5).');

  final rows = uploadedSheet.rows.skip(1);
  var rowNumber = 1;
  var newCount = 0;
  var updateCount = 0;
  for (final row in rows) {
    rowNumber++;
    final docId = cellString(row, 0);
    final hadithNumberRaw = cellString(row, 1);
    final text = cellString(row, 2).trim();
    final orderRaw = cellString(row, 3);
    print('  row $rowNumber -> docId="$docId" hadith="$hadithNumberRaw" '
        'text="$text" order="$orderRaw"');
    if (docId.isEmpty && text.isNotEmpty) newCount++;
    if (docId.isNotEmpty) updateCount++;
  }

  print('\nResult: $updateCount rows recognized as updates, '
      '$newCount rows recognized as new.');
  print(newCount == 1 && updateCount == 3
      ? 'PASS — the excel package + our parsing logic correctly detect '
          'an appended row. The bug is not reproducible at this level; '
          'it likely comes from how the real spreadsheet app the user '
          'edits with saved the file (e.g. a formula-based cell, an '
          'autosave/focus issue, or uploading a stale copy of the file).'
      : 'FAIL — reproduced the bug: the appended row was lost or '
          'misread by the excel package/parsing logic.');
}
