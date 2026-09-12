// Unit tests for lib/features/dashboard/bulk_add_parsing.dart — the
// add-only bulk-upload rewrite (no docId column, create-only for both
// moderators and admins). Imports the real parsing code directly (unlike
// tool/test_excel_roundtrip.dart, which predates this module and
// re-implements the loop it's checking) so a change to the actual app
// logic can't silently drift away from what this test verifies.
//
// Run with: dart run tool/test_bulk_add_parsing.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;

import '../lib/features/dashboard/bulk_add_parsing.dart' as parsing;

var _failures = 0;
var _checks = 0;

void expect(bool condition, String description) {
  _checks++;
  if (!condition) {
    _failures++;
    print('FAIL: $description');
  }
}

void expectEquals(Object? actual, Object? expected, String description) {
  expect(actual == expected, '$description (expected $expected, got $actual)');
}

xls.Sheet sheetFrom(List<List<String>> rows) {
  final workbook = xls.Excel.createExcel();
  final sheet = workbook['s'];
  for (final row in rows) {
    sheet.appendRow(row.map(xls.TextCellValue.new).toList());
  }
  // Round-trip through encode/decode, like a real upload, rather than
  // handing back the in-memory sheet the excel package just built — this
  // is exactly the gap that hid the "added row not detected" bug
  // tool/test_excel_roundtrip.dart was written for.
  final bytes = workbook.encode()!;
  final reopened = xls.Excel.decodeBytes(Uint8List.fromList(bytes));
  return reopened.tables['s']!;
}

void main() {
  // ---------------------------------------------------------- headers ----

  {
    final sheet = sheetFrom([parsing.dailyAddHeaders]);
    expectEquals(
      parsing.headerMismatchNote(sheet, parsing.dailyAddHeaders),
      null,
      'exact daily add-template header matches',
    );
  }
  {
    final sheet = sheetFrom([parsing.communityAddHeaders]);
    expectEquals(
      parsing.headerMismatchNote(sheet, parsing.communityAddHeaders),
      null,
      'exact community add-template header matches',
    );
  }
  {
    final sheet = sheetFrom([parsing.notificationAddHeaders]);
    expectEquals(
      parsing.headerMismatchNote(sheet, parsing.notificationAddHeaders),
      null,
      'exact notification add-template header matches',
    );
  }
  {
    // The exact scenario this rewrite exists to prevent: an admin
    // re-uploads their read-only "current data" export (docId first
    // column) instead of the add template.
    final sheet = sheetFrom([
      ['المعرف', 'رقم الحديث', 'النص', 'الترتيب'],
      ['abc123', '1', 'نص قديم', '100'],
    ]);
    final note = parsing.headerMismatchNote(sheet, parsing.dailyAddHeaders);
    expect(note != null, 'current-data export header is rejected, not silently misread');
    expect(
      note != null && note.contains('البيانات الحالية'),
      'rejection message specifically names the current-data export',
    );
  }
  {
    final sheet = sheetFrom([
      ['عمود', 'آخر'],
    ]);
    final note = parsing.headerMismatchNote(sheet, parsing.dailyAddHeaders);
    expect(note != null, 'unrelated header layout is rejected');
    expect(
      note != null && !note.contains('البيانات الحالية'),
      'unrelated header layout gets the generic message, not the current-data hint',
    );
  }
  {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['empty'];
    expect(
      parsing.headerMismatchNote(sheet, parsing.dailyAddHeaders) != null,
      'a sheet with no header row at all is rejected, not crashed on',
    );
  }

  // ------------------------------------------------------ dailyMessages ---

  {
    final sheet = sheetFrom([
      parsing.dailyAddHeaders,
      ['1', 'نص أول للحديث ١'],
      ['1', 'نص ثانٍ لنفس الحديث'],
      ['2', 'نص للحديث ٢'],
      ['', ''], // blank row — must be silently skipped
      ['99', 'رقم حديث خارج النطاق'],
      ['3', ''], // blank text — invalid, not silently dropped
      ['٤', 'رقم بأرقام هندية يجب أن يُطبَّع'], // Arabic-Indic '4'
    ]);
    final result = parsing.parseDailyRows(sheet);

    expectEquals(
      result.newRowsByHadith[1]?.length,
      2,
      'both rows for hadith 1 are grouped together, in order',
    );
    expectEquals(
      result.newRowsByHadith[1]?[0],
      'نص أول للحديث ١',
      'hadith 1 rows keep their original order',
    );
    expectEquals(
      result.newRowsByHadith[2]?.length,
      1,
      'hadith 2 has exactly one new row',
    );
    expect(
      result.newRowsByHadith.containsKey(99) == false,
      'out-of-range hadith number (99) never reaches newRowsByHadith',
    );
    expect(
      result.invalidRows.any((r) => r.contains('رقم حديث غير صحيح')),
      'out-of-range hadith number is reported as invalid',
    );
    expect(
      result.invalidRows.any((r) => r.contains('نص فارغ')),
      'blank text with a valid hadith number is reported as invalid',
    );
    expectEquals(
      result.newRowsByHadith[4]?.single,
      'رقم بأرقام هندية يجب أن يُطبَّع',
      'Arabic-Indic digit "٤" normalizes to hadith 4',
    );
    expectEquals(
      result.newRowsByHadith.values.fold<int>(0, (n, l) => n + l.length),
      4,
      'exactly 4 valid rows total (2 for hadith 1, 1 for hadith 2, 1 for hadith 4)',
    );
  }

  // -------------------------------------------------- communityMessages ---

  {
    final sheet = sheetFrom([
      parsing.communityAddHeaders,
      ['5', 'مشاركة بدون اسم كاتب ولا ترتيب', '', ''],
      ['6', 'مشاركة باسم كاتب وترتيب', 'فاعل خير', '250'],
      ['0', 'رقم حديث غير صحيح'],
      ['7', 'a' * 2001], // too long
    ]);
    final result = parsing.parseCommunityRows(sheet);

    expectEquals(result.creates.length, 2, 'exactly 2 valid community rows parsed');
    expectEquals(
      result.creates[0]['authorName'],
      'لوحة الإشراف',
      'blank author name defaults to لوحة الإشراف',
    );
    expect(
      !result.creates[0].containsKey('order'),
      'omitted order column means no order key at all (no default for community)',
    );
    expectEquals(result.creates[1]['authorName'], 'فاعل خير', 'explicit author name is kept');
    expectEquals(result.creates[1]['order'], 250, 'explicit order value is parsed as an int');
    expectEquals(result.creates[0]['status'], 'approved', 'every bulk-added community row is approved by default');
    expect(
      result.invalidRows.any((r) => r.contains('رقم حديث غير صحيح')),
      'hadith number 0 is rejected as out of range',
    );
    expect(
      result.invalidRows.any((r) => r.contains('أطول من')),
      'a message over 2000 chars is rejected',
    );
    expect(
      !result.creates.any((c) => c.containsKey('authorUid')),
      'authorUid is intentionally NOT set here — the caller stamps it (pure module has no Auth access)',
    );
  }

  // ------------------------------------------------ notificationMessages ---

  {
    final sheet = sheetFrom([
      parsing.notificationAddHeaders,
      ['رسالة بلا خيارات', '', ''],
      ['رسالة غير نشطة', 'لا', ''],
      ['رسالة بترتيب محدد', 'نعم', '999'],
      ['a' * 301, '', ''], // too long
      ['رسالة بقيمة غير صحيحة', 'ربما', ''],
    ]);
    final result = parsing.parseNotificationRows(sheet, startSeq: 10);

    expectEquals(result.creates.length, 3, 'exactly 3 valid notification rows parsed');
    expectEquals(result.creates[0]['active'], true, 'blank "نشطة" defaults to active=true');
    expectEquals(result.creates[0]['order'], 10, 'first row with no explicit order gets startSeq');
    expectEquals(result.creates[1]['active'], false, '"لا" maps to active=false');
    expectEquals(result.creates[1]['order'], 11, 'sequential order increments per row lacking an explicit value');
    expectEquals(result.creates[2]['order'], 999, 'an explicit order value is not overridden by the sequence counter');
    expect(
      result.invalidRows.any((r) => r.contains('أطول من')),
      'a notification text over 300 chars is rejected',
    );
    expect(
      result.invalidRows.any((r) => r.contains('نعم أو لا')),
      'an unrecognized "نشطة" value is rejected rather than silently defaulted',
    );
  }

  print('\n$_checks checks, $_failures failures.');
  if (_failures > 0) {
    print('FAILED');
    exit(1);
  }
  print('PASSED — bulk_add_parsing.dart behaves as expected.');
}
