/// Eastern Arabic-Indic numerals.
///
/// This was previously copy-pasted into four screens as a private method.
const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String toArabicDigits(int number) {
  final buffer = StringBuffer();
  final text = number.toString();

  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i) - 0x30; // '0'
    buffer.write(code >= 0 && code <= 9 ? _arabicDigits[code] : text[i]);
  }

  return buffer.toString();
}

/// First character of a name, for avatar initials. Guards against empty names
/// and against splitting a multi-code-unit grapheme in half.
String firstInitial(String name, {String fallback = 'م'}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return fallback;

  final firstUnit = trimmed.codeUnitAt(0);
  final isSurrogatePair =
      firstUnit >= 0xD800 && firstUnit <= 0xDBFF && trimmed.length > 1;

  return trimmed.substring(0, isSurrogatePair ? 2 : 1);
}
