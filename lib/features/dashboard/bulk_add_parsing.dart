/// Pure (no Firestore, no Auth) row-parsing helpers for [BulkAddPage]'s
/// add-only Excel upload — split out from bulk_add_page.dart so
/// tool/test_bulk_add_parsing.dart can exercise the actual parsing logic
/// directly instead of re-implementing it in the test (which would risk
/// the test and the app quietly drifting apart). Only the parts that
/// genuinely need Firestore — assigning a fresh sequential `order` to new
/// rows — stay in bulk_add_page.dart itself.
library;

import 'package:excel/excel.dart' as xls;

const arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Excel round trips through Arabic locales sometimes leave numeric cells
/// as Arabic-Indic digits (٠-٩) instead of ASCII ones — int.tryParse
/// doesn't understand those, so normalize before parsing.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final ch in input.codeUnits) {
    final index = arabicIndicDigits.codeUnits.indexOf(ch);
    buffer.writeCharCode(index == -1 ? ch : 0x30 + index);
  }
  return buffer.toString();
}

String cellString(List<xls.Data?> row, int index) {
  if (index >= row.length) return '';
  return row[index]?.value?.toString().trim() ?? '';
}

/// Compares a sheet's header row against the expected add-template headers
/// (order-sensitive, exact match) and, if they don't match, returns a
/// human-readable Arabic explanation instead of silently misreading
/// columns. The single most likely mismatch is an admin re-uploading their
/// read-only "current data" export by mistake — that file's first column
/// is "المعرف", so it gets a specific, actionable hint rather than the
/// generic message.
String? headerMismatchNote(xls.Sheet sheet, List<String> expected) {
  if (sheet.rows.isEmpty) {
    return 'الورقة فارغة تماماً حتى بدون عناوين الأعمدة — نزّل نموذج '
        'الإضافة من جديد';
  }
  final header = sheet.rows.first;
  final actual = [for (var i = 0; i < expected.length; i++) cellString(header, i)];
  var matches = true;
  for (var i = 0; i < expected.length; i++) {
    if (actual[i] != expected[i]) {
      matches = false;
      break;
    }
  }
  if (matches) return null;

  if (cellString(header, 0) == 'المعرف') {
    return 'يبدو أنك رفعت ملف "البيانات الحالية" (للعرض فقط) بدلاً من '
        'نموذج الإضافة — نزّل "نموذج الإضافة" من الأعلى وأضف الرسائل '
        'الجديدة فيه فقط.';
  }
  return 'عناوين الأعمدة لا تطابق نموذج الإضافة المتوقع '
      '(${expected.join('، ')}) — نزّل نموذج الإضافة من جديد ولا تُغيّر '
      'عناوين الأعمدة.';
}

const dailyAddHeaders = ['رقم الحديث', 'النص'];
const communityAddHeaders = [
  'رقم الحديث',
  'النص',
  'اسم الكاتب (اختياري)',
  'الترتيب (اختياري)',
];
const notificationAddHeaders = [
  'النص',
  'نشطة؟ نعم أو لا (اختياري)',
  'الترتيب (اختياري)',
];

/// Result of parsing the "رسائل اليوم" sheet: valid rows grouped by hadith
/// number (in the order they appeared, since that's the order new rows for
/// the same hadith should be sequenced), plus any per-row errors. Building
/// the actual Firestore documents still needs a per-hadith starting
/// sequence number from Firestore, so that step stays in bulk_add_page.dart.
class DailyRowsParseResult {
  DailyRowsParseResult(this.newRowsByHadith, this.invalidRows);

  final Map<int, List<String>> newRowsByHadith;
  final List<String> invalidRows;
}

DailyRowsParseResult parseDailyRows(xls.Sheet sheet) {
  final rows = sheet.rows.skip(1);
  final newRowsByHadith = <int, List<String>>{};
  final invalidRows = <String>[];

  var rowNumber = 1;
  for (final row in rows) {
    rowNumber++;
    final hadithNumberRaw = cellString(row, 0);
    final text = cellString(row, 1).trim();

    if (hadithNumberRaw.isEmpty && text.isEmpty) continue;

    final hadithNumber = int.tryParse(normalizeDigits(hadithNumberRaw));
    if (hadithNumber == null || hadithNumber < 1 || hadithNumber > 42) {
      invalidRows.add('$rowNumber (رقم حديث غير صحيح)');
      continue;
    }
    if (text.isEmpty) {
      invalidRows.add('$rowNumber (نص فارغ)');
      continue;
    }
    newRowsByHadith.putIfAbsent(hadithNumber, () => []).add(text);
  }

  return DailyRowsParseResult(newRowsByHadith, invalidRows);
}

/// Fully pure: a community-message create needs no Firestore read to be
/// built (unlike dailyMessages/notificationMessages, it has no auto
/// sequential `order` fallback), so this returns Firestore-ready field maps
/// directly (still missing `authorUid`, stamped by the caller who has
/// access to FirebaseAuth).
class CommunityRowsParseResult {
  CommunityRowsParseResult(this.creates, this.invalidRows);

  final List<Map<String, dynamic>> creates;
  final List<String> invalidRows;
}

CommunityRowsParseResult parseCommunityRows(xls.Sheet sheet) {
  final rows = sheet.rows.skip(1);
  final creates = <Map<String, dynamic>>[];
  final invalidRows = <String>[];

  var rowNumber = 1;
  for (final row in rows) {
    rowNumber++;
    final hadithNumberRaw = cellString(row, 0);
    final text = cellString(row, 1).trim();
    final authorName = cellString(row, 2).trim();
    final orderRaw = cellString(row, 3);

    if (hadithNumberRaw.isEmpty && text.isEmpty) continue;

    final hadithNumber = int.tryParse(normalizeDigits(hadithNumberRaw));
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

    final order = orderRaw.isEmpty ? null : int.tryParse(normalizeDigits(orderRaw));

    creates.add({
      'authorName': authorName.isEmpty ? 'لوحة الإشراف' : authorName,
      'hadithNumber': hadithNumber,
      'message': text,
      'status': 'approved',
      'likeCount': 0,
      if (order != null) 'order': order,
    });
  }

  return CommunityRowsParseResult(creates, invalidRows);
}

/// [startSeq] is the sequential order value the first new row without an
/// explicit "الترتيب" should get (one past however many notificationMessages
/// docs already exist) — injected so this stays Firestore-free and testable.
class NotificationRowsParseResult {
  NotificationRowsParseResult(this.creates, this.invalidRows);

  final List<Map<String, dynamic>> creates;
  final List<String> invalidRows;
}

NotificationRowsParseResult parseNotificationRows(
  xls.Sheet sheet, {
  required int startSeq,
}) {
  final rows = sheet.rows.skip(1);
  final creates = <Map<String, dynamic>>[];
  final invalidRows = <String>[];

  var rowNumber = 1;
  var newSeq = startSeq;
  for (final row in rows) {
    rowNumber++;
    final text = cellString(row, 0).trim();
    final activeRaw = cellString(row, 1).trim();
    final orderRaw = cellString(row, 2);

    if (text.isEmpty) continue;
    if (text.length > 300) {
      invalidRows.add('$rowNumber (النص أطول من ٣٠٠ حرف)');
      continue;
    }

    bool active = true;
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

    final order = orderRaw.isEmpty ? null : int.tryParse(normalizeDigits(orderRaw));

    creates.add({
      'text': text,
      'active': active,
      'order': order ?? newSeq,
    });
    newSeq++;
  }

  return NotificationRowsParseResult(creates, invalidRows);
}
