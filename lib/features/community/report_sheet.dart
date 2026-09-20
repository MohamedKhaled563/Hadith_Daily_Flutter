import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/insight.dart';
import '../../data/services/moderation_service.dart';

/// What the sheet did, so the caller can react — a blocked author means the
/// screen the reader is on is about to be hidden from them.
enum ModerationOutcome { none, reported, blocked }

/// Popped as a route result when a screen closes itself because its author was
/// just blocked, so the feed underneath knows to rebuild and say why.
const kAuthorBlocked = 'author-blocked';

/// Report a message, or stop seeing its author.
///
/// Kept as one sheet because from the reader's side these are the same
/// impulse — "I don't want this" — with two different answers: tell someone,
/// or just make it go away. Splitting them into two entry points would make
/// the reader choose the remedy before they have described the problem.
Future<ModerationOutcome> showReportSheet(
  BuildContext context,
  CommunityPost post,
) async {
  final outcome = await showBotanicalSheet<ModerationOutcome>(
    context: context,
    title: 'الإبلاغ عن المشاركة',
    subtitle: 'ستصل ملاحظتك لفريق الإشراف، ولن يعرف صاحب المشاركة من أبلغ',
    child: _ReportForm(post: post),
  );
  return outcome ?? ModerationOutcome.none;
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({required this.post});

  final CommunityPost post;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _moderation = ModerationService();
  final _noteController = TextEditingController();

  ReportReason? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'اختر سبب الإبلاغ');
      return;
    }

    // A report is only worth filing if someone stands behind it, and the
    // rules require an author anyway.
    if (!await requireSignIn(
      context,
      reason: 'سجّل الدخول حتى يتمكن فريق الإشراف من متابعة بلاغك',
    )) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _moderation.report(
        postId: widget.post.id,
        reason: reason,
        note: _noteController.text,
      );
      if (!mounted) return;
      AppHaptics.success();
      Navigator.pop(context, ModerationOutcome.reported);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر إرسال البلاغ، تحقق من اتصالك وحاول مرة أخرى';
      });
      debugPrint('report failed: $error');
    }
  }

  Future<void> _block() async {
    AppHaptics.toggle();
    await _moderation.setBlocked(widget.post.authorName, true);
    if (!mounted) return;
    Navigator.pop(context, ModerationOutcome.blocked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in ReportReason.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReasonOption(
              label: reason.label,
              selected: _reason == reason,
              onTap: _busy
                  ? null
                  : () {
                      AppHaptics.selection();
                      setState(() {
                        _reason = reason;
                        _error = null;
                      });
                    },
            ),
          ),

        const SizedBox(height: 6),

        Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadii.listItem),
            border: Border.all(color: palette.cardBorder, width: 1.2),
          ),
          child: TextField(
            controller: _noteController,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 500,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              color: palette.bodyText,
            ),
            decoration: InputDecoration(
              hintText: 'تفاصيل إضافية (اختياري)',
              hintStyle: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                color: palette.mutedText,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: palette.danger),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        AppButton(
          text: _busy ? 'جارٍ الإرسال…' : 'إرسال البلاغ',
          icon: _busy ? null : Icons.flag_outlined,
          onPressed: _busy ? null : _submit,
        ),

        const SizedBox(height: 18),
        Divider(color: palette.cardBorder, height: 1),
        const SizedBox(height: 14),

        Text(
          'أو أخفِ كل مشاركات «${widget.post.authorName}» عن هذا الجهاز. '
          'لن يُبلَّغ بذلك، ويمكنك التراجع من الإعدادات.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: 10),
        AppButton(
          text: 'إخفاء مشاركات هذا الكاتب',
          isSecondary: true,
          icon: Icons.visibility_off_outlined,
          onPressed: _busy ? null : _block,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: palette.mutedText,
          ),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap ?? () {},
      semanticLabel: label,
      selected: selected,
      minSize: 48,
      pressScale: AppPress.cardScale,
      child: AnimatedContainer(
        duration: context.motion(AppDurations.control),
        curve: AppDurations.curve,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.surface : palette.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.listItem),
          border: Border.all(
            color: selected ? palette.cardBorderStrong : palette.cardBorder,
            width: selected ? 1.4 : 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? palette.goldText : palette.mutedText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13.5,
                  height: AppLeading.body,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? palette.bodyText : palette.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The other half of blocking: getting back out of it.
///
/// A block the reader cannot undo is a trap, and the feed's empty state
/// promises this screen by name, so it has to exist.
Future<void> showBlockedAuthorsSheet(BuildContext context) {
  return showBotanicalSheet<void>(
    context: context,
    title: 'الكُتّاب المخفيون',
    subtitle: 'مشاركاتهم مخفية على هذا الجهاز وحده',
    child: const _BlockedAuthorsList(),
  );
}

class _BlockedAuthorsList extends StatefulWidget {
  const _BlockedAuthorsList();

  @override
  State<_BlockedAuthorsList> createState() => _BlockedAuthorsListState();
}

class _BlockedAuthorsListState extends State<_BlockedAuthorsList> {
  final _moderation = ModerationService();

  Future<void> _unblock(String name) async {
    AppHaptics.toggle();
    await _moderation.setBlocked(name, false);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final names = _moderation.blockedAuthors.toList()..sort();

    if (names.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'لم تُخفِ أحداً بعد.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.listItem),
                border: Border.all(color: palette.cardBorder, width: 1.1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 14,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w600,
                        color: palette.bodyText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _unblock(name),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: palette.goldText,
                    ),
                    child: const Text('إظهار'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown after the sheet closes, so the caller does not repeat the copy.
void showModerationOutcome(BuildContext context, ModerationOutcome outcome) {
  switch (outcome) {
    case ModerationOutcome.reported:
      showAppSnack(
        context,
        'وصل بلاغك لفريق الإشراف، شكراً لك',
        tone: SnackTone.success,
      );
    case ModerationOutcome.blocked:
      showAppSnack(
        context,
        'لن تظهر لك مشاركات هذا الكاتب على هذا الجهاز',
        tone: SnackTone.neutral,
      );
    case ModerationOutcome.none:
      break;
  }
}
