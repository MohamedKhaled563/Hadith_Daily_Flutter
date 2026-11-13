import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/models/hadith.dart';
import 'journey_tree.dart';

/// What the reader chose from the completion sheet.
enum CompletionChoice { write, share, memorize }

/// The moment a hadith is finished: the leaf turns gold, and writing about it
/// is one tap away. Sharing is offered only at a milestone (5, 10, 20, 30
/// and 42 hadiths). Null when the sheet is just dismissed.
Future<CompletionChoice?> showCompletionSheet({
  required BuildContext context,
  required Hadith hadith,
  required ReadingOutcome outcome,
  bool canMemorize = false,
}) {
  final milestone = outcome.milestone == null
      ? null
      : JourneyCopy.milestone(outcome.milestone!);

  return showBotanicalSheet<CompletionChoice>(
    context: context,
    title: milestone?.title ??
        (outcome.firstTime
            ? 'اكتمل حديث «${hadith.title}»'
            : 'أتممت قراءته مرة أخرى'),
    subtitle: milestone?.body ??
        JourneyCopy.streakLine(outcome.streak.current, outcome.streak.best),
    child: _CompletionBody(
      outcome: outcome,
      canMemorize: canMemorize,
      isMilestone: milestone != null,
    ),
  );
}

class _CompletionBody extends StatelessWidget {
  const _CompletionBody({
    required this.outcome,
    required this.isMilestone,
    this.canMemorize = false,
  });

  final ReadingOutcome outcome;

  /// Offers to learn the hadith by heart, unless it already is.
  final bool canMemorize;

  /// A milestone's message takes the subtitle, so the streak line moves
  /// here, and only a milestone offers to share.
  final bool isMilestone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: CompletedLeaf()),
        const SizedBox(height: 8),
        Text(
          '${toArabicDigits(outcome.completeCount)} من ٤٢ حديثاً',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
            color: palette.goldText,
          ),
        ),
        if (isMilestone) ...[
          const SizedBox(height: 4),
          Text(
            JourneyCopy.streakLine(outcome.streak.current, outcome.streak.best),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13,
              height: AppLeading.chrome,
              color: palette.mutedText,
            ),
          ),
        ],
        if (outcome.record != null || outcome.newBest) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: palette.warmWash,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                outcome.record?.brokenLine ?? 'أطول سلسلة لك حتى الآن',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: palette.warmText,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          JourneyCopy.writePrompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            height: AppLeading.body,
            color: palette.bodyText,
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'اكتب رسالة من هذا الحديث',
          icon: Icons.edit_note_rounded,
          onPressed: () => Navigator.pop(context, CompletionChoice.write),
        ),
        if (isMilestone) ...[
          const SizedBox(height: 10),
          AppButton(
            text: 'مشاركة',
            isSecondary: true,
            icon: Icons.ios_share_rounded,
            onPressed: () => Navigator.pop(context, CompletionChoice.share),
          ),
        ],
        if (canMemorize) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, CompletionChoice.memorize),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: palette.goldText,
            ),
            icon: const Icon(Icons.psychology_alt_rounded, size: 20),
            label: const Text('احفظ هذا الحديث'),
          ),
        ],
        if (JourneyRepository().isGuest) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              await requireSignIn(context, reason: JourneyCopy.signInReason);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: palette.goldText,
            ),
            child: const Text('سجّل الدخول لتبقى شجرتك معك'),
          ),
        ],
      ],
    );
  }
}
