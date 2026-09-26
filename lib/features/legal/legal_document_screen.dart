import 'package:flutter/material.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';

/// The privacy policy and the terms of use, read inside the app.
///
/// Sign-up blocks on agreeing to both, and until now neither existed anywhere
/// in the project — the checkbox was plain text with nothing behind it, so a
/// reader was agreeing to something they could not read. Both stores also
/// require a reachable policy, and Play Console additionally wants a URL for
/// the listing; `web/privacy-policy.html` and `web/terms-of-use.html` carry
/// the same words for that.
///
/// The text is deliberately not Markdown-rendered by a package: it is two
/// documents with one structural device between them (a `##` heading), so a
/// split on the line prefix is the whole parser and the app keeps its
/// dependency list as it is.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  /// Pushes the privacy policy.
  static Future<void> openPrivacy(BuildContext context) => Navigator.push(
        context,
        appPageRoute(
          child: const LegalDocumentScreen(
            title: LegalDocuments.privacyTitle,
            body: LegalDocuments.privacy,
          ),
        ),
      );

  /// Pushes the terms of use.
  static Future<void> openTerms(BuildContext context) => Navigator.push(
        context,
        appPageRoute(
          child: const LegalDocumentScreen(
            title: LegalDocuments.termsTitle,
            body: LegalDocuments.terms,
          ),
        ),
      );

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const EmblemBadge(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  // chevron_right reads as "back" under RTL.
                  child: CircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    semanticLabel: 'رجوع',
                    onTap: () => Navigator.maybePop(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'آخر تحديث: ${LegalDocuments.lastUpdated}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.goldText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ParchmentCard(
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _blocks(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Splits the document on blank lines and gives `##` headings and `•`
  /// bullets their own treatment. Everything else is a paragraph.
  List<Widget> _blocks(BuildContext context) {
    final palette = context.palette;
    final widgets = <Widget>[];

    for (final raw in body.trim().split('\n\n')) {
      final block = raw.trim();
      if (block.isEmpty) continue;

      if (block.startsWith('## ')) {
        widgets
          ..add(SizedBox(height: widgets.isEmpty ? 0 : 20))
          ..add(
            Text(
              block.substring(3).trim(),
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 16,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: palette.goldText,
              ),
            ),
          )
          ..add(const SizedBox(height: 10));
        continue;
      }

      if (block.startsWith('• ')) {
        for (final line in block.split('\n')) {
          final item = line.trim();
          if (item.isEmpty) continue;
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.goldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.startsWith('• ') ? item.substring(2) : item,
                      textAlign: TextAlign.start,
                      style: _body(palette),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        continue;
      }

      widgets
        ..add(_RichParagraph(text: block, style: _body(palette)))
        ..add(const SizedBox(height: 12));
    }

    return widgets;
  }

  TextStyle _body(BotanicalPalette palette) => TextStyle(
        fontFamily: kSans,
        fontSize: 14.5,
        height: AppLeading.body,
        color: palette.bodyText,
      );
}

/// Renders `**bold**` runs inside a paragraph. The documents use it for the
/// lead-in of each clause ("**بيانات الحساب.**"), which is the only inline
/// mark either of them needs.
class _RichParagraph extends StatelessWidget {
  const _RichParagraph({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var rest = text;

    while (true) {
      final open = rest.indexOf('**');
      if (open < 0) break;
      final close = rest.indexOf('**', open + 2);
      if (close < 0) break;

      if (open > 0) spans.add(TextSpan(text: rest.substring(0, open)));
      spans.add(
        TextSpan(
          text: rest.substring(open + 2, close),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      rest = rest.substring(close + 2);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.start,
      style: style,
    );
  }
}
