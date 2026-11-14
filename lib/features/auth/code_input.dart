import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_panel.dart';

/// The six-digit code box shared by email confirmation and password reset,
/// with a «لصق الرمز» button under it.
///
/// No app can read the reader's Gmail, so an emailed code can't fill itself
/// in the way an SMS code can. The closest is: copy it from the email (or the
/// notification), come back, tap paste. The button reads the clipboard only
/// when tapped (Android 12+ shows a "pasted from clipboard" notice each time
/// an app reads it, so it is never read in the background), pulls the six
/// digits out of whatever was copied, and hands them to [onComplete] at once.
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    required this.onComplete,
    required this.onEdited,
    required this.onNothingToPaste,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool autofocus;

  /// Called with the code once all six digits are in, typed or pasted.
  final ValueChanged<String> onComplete;

  /// Called on every change, so the screen can clear an old error.
  final VoidCallback onEdited;

  /// Called when paste is tapped but the clipboard holds no code.
  final VoidCallback onNothingToPaste;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = extractCode(data?.text ?? '');
    if (code == null) {
      onNothingToPaste();
      return;
    }
    controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    onEdited();
    onComplete(code);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassField(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [CodeDigitsFormatter()],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            onChanged: (value) {
              onEdited();
              if (value.length == 6) onComplete(value);
            },
            onSubmitted: onComplete,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: palette.bodyText,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                fontSize: 22,
                letterSpacing: 10,
                color: palette.mutedText,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: enabled ? _paste : null,
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text(
              'لصق الرمز',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: palette.goldText,
            ),
          ),
        ),
      ],
    );
  }
}

/// The first six digits in [text], as ASCII, or null if there are fewer.
///
/// Copied text is rarely just the code: it may carry spaces or dashes, the
/// whole subject line («رمز تأكيد بريدك…: 482913»), or Arabic-Indic digits.
/// A run of exactly six is preferred, so a longer number elsewhere in the
/// text isn't chopped up.
String? extractCode(String text) {
  final normalized = _asciiDigits(text);
  final exact = RegExp(r'(?<![0-9])[0-9]{6}(?![0-9])').firstMatch(normalized);
  if (exact != null) return exact.group(0);
  final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length == 6 ? digits : null;
}

String _asciiDigits(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x660 && rune <= 0x669) {
      buffer.writeCharCode(rune - 0x660 + 0x30);
    } else if (rune >= 0x6F0 && rune <= 0x6F9) {
      buffer.writeCharCode(rune - 0x6F0 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Keeps the field to six ASCII digits. Arabic keyboards type ٠-٩ (and
/// Persian ones ۰-۹); those are turned into 0-9 rather than refused, and
/// anything else — spaces or dashes from a pasted code — is dropped.
class CodeDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _asciiDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    final text = digits.length > 6 ? digits.substring(0, 6) : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
