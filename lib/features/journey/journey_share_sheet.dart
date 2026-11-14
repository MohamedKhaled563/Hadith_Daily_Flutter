import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_links.dart';
import '../../core/share/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_points.dart';
import '../../data/journey/journey_repository.dart';
import 'journey_posters.dart';
import 'journey_tree.dart';

typedef PosterBuilder = Widget Function(PosterFormat format, String? name);

/// Shares the reader's tree.
Future<void> shareTree(BuildContext context) async {
  final data = JourneyRepository().data;
  // The poster paints the tree straight away, so it must be decoded first.
  // It almost always is: the tree on the screen behind loaded it.
  await TreeArt.load();
  if (!context.mounted) return;
  return _showPosterSheet(
    context: context,
    caption: JourneyCopy.treeCaption(data.completeCount, AppLinks.storeLink),
    builder: (format, name) =>
        TreePoster(format: format, data: data, name: name),
  );
}

/// Shares a milestone the reader has just reached, in the milestone's own
/// words: on the poster, and as the text beside it or copied.
Future<void> shareMilestone(BuildContext context, int milestone) {
  return _showPosterSheet(
    context: context,
    caption: JourneyCopy.milestoneCaption(milestone, AppLinks.storeLink),
    builder: (format, name) =>
        MilestonePoster(format: format, milestone: milestone, name: name),
  );
}

/// Shares the week so far.
Future<void> shareHarvest(BuildContext context) {
  final journey = JourneyRepository();
  final harvest = harvestFor(
    journey.data,
    journey.today,
    approvedOn: journey.approvedOn,
  );
  return _showPosterSheet(
    context: context,
    caption: JourneyCopy.harvestCaption(harvest, AppLinks.storeLink),
    builder: (format, name) => HarvestPoster(
      format: format,
      harvest: harvest,
      weekLabel: 'أسبوع ${JourneyCopy.boardWeek(weekStartKey(journey.today))}',
      name: name,
    ),
  );
}

/// Shows the poster the reader is about to send, as the message share sheet
/// does, with a choice of shape and of whether their name is on it.
Future<void> _showPosterSheet({
  required BuildContext context,
  required String caption,
  required PosterBuilder builder,
}) {
  return showBotanicalSheet<void>(
    context: context,
    title: 'ادعُ غيرك إلى القراءة معك',
    subtitle: 'تُرسل كصورة، ويمكنك اختيار شكلها',
    child: _PosterSheetBody(
      hostContext: context,
      caption: caption,
      builder: builder,
    ),
  );
}

class _PosterSheetBody extends StatefulWidget {
  const _PosterSheetBody({
    required this.hostContext,
    required this.caption,
    required this.builder,
  });

  /// The screen behind the sheet. Sharing outlives the sheet, which closes
  /// first, so the overlay and the render hang off this context.
  final BuildContext hostContext;
  final String caption;
  final PosterBuilder builder;

  @override
  State<_PosterSheetBody> createState() => _PosterSheetBodyState();
}

class _PosterSheetBodyState extends State<_PosterSheetBody> {
  static const _previewHeight = 300.0;

  var _format = PosterFormat.feed;

  /// Off until the reader turns it on. A poster goes further than they can
  /// see, so showing their name is their decision each time.
  var _showName = false;

  String? get _name {
    final state = AppStateController();
    return _showName && state.isLoggedIn ? state.userName : null;
  }

  Future<void> _share() async {
    final host = widget.hostContext;
    final poster = widget.builder(_format, _name);
    final size = _format.size;

    Navigator.pop(context);
    showAppLoadingOverlay(host, message: 'جارٍ تجهيز البطاقة…');
    try {
      await ShareService.sharePoster(
        context: host,
        poster: poster,
        size: size,
        caption: widget.caption,
      );
    } finally {
      hideAppLoadingOverlay();
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.caption));
    Navigator.pop(context);
    showAppSnack(widget.hostContext, 'تم نسخ النص', tone: SnackTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = _format.size;
    final signedIn = AppStateController().isLoggedIn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A scaled-down view of the exact poster that will be sent.
        Center(
          child: DecoratedBox(
            // Framed like a print on the table, so the preview reads as the
            // card that will be sent rather than part of the sheet.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorderStrong, width: 1.2),
              boxShadow: AppElevation.hero(isDark: context.isDarkMode),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: _previewHeight,
                width: _previewHeight * size.width / size.height,
                child: FittedBox(
                  child: widget.builder(_format, _name),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final format in PosterFormat.values) ...[
              _FormatChip(
                label: format.label,
                selected: format == _format,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _format = format);
                },
              ),
              if (format != PosterFormat.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        if (signedIn) ...[
          const SizedBox(height: 6),
          SwitchListTile(
            value: _showName,
            onChanged: (value) => setState(() => _showName = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'إظهار اسمي',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w600,
                color: palette.bodyText,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
          text: 'مشاركة الصورة',
          icon: Icons.ios_share_rounded,
          onPressed: _share,
        ),
        const SizedBox(height: 10),
        AppButton(
          text: 'نسخ النص',
          isSecondary: true,
          icon: Icons.copy_rounded,
          onPressed: _copy,
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      child: AnimatedContainer(
        duration: context.motion(AppDurations.control),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.successWash : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? palette.success : palette.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 13,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
            color: selected ? palette.success : palette.mutedText,
          ),
        ),
      ),
    );
  }
}
