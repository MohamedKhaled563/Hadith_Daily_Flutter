import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/journey_points.dart';
import 'journey_tree.dart';

/// The shapes a progress poster comes in. Captured at 3×, so these are
/// 1080×1350 for a feed and 1080×1920 for a Status or a Story.
enum PosterFormat {
  feed(Size(360, 450), 'منشور'),
  story(Size(360, 640), 'حالة');

  const PosterFormat(this.size, this.label);

  final Size size;
  final String label;
}

const _ink = Color(0xFF243329);
const _gold = Color(0xFF7A5B0E);
const _green = Color(0xFF5A7061);

/// The ground every progress poster shares, matching [ShareCard]: always the
/// light, warm treatment, whichever mode the reader happens to be in.
///
/// Every poster says how to find the app in its own words. A Status or a
/// Story drops the caption, and the link with it, so the image has to carry
/// the way back by itself.
class _PosterFrame extends StatelessWidget {
  const _PosterFrame({required this.format, required this.child});

  final PosterFormat format;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox.fromSize(
        size: format.size,
        child: Material(
          color: const Color(0xFFF2ECE0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF6F1E7),
                      Color(0xFFEFE7D8),
                      Color(0xFFE7DCC9),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicWatermarkPainter(
                    color: const Color(0x22B89F70),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Opacity(
                  opacity: 0.55,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_top_right.png',
                    width: 96,
                    height: 108,
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                left: -6,
                child: Opacity(
                  opacity: 0.55,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.png',
                    width: 96,
                    height: 108,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x66B89F70),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
                child: Column(
                  children: [
                    Expanded(child: child),
                    const SizedBox(height: 10),
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/golden_divider.png',
                      width: 100,
                      height: 12,
                      fallback: Container(
                        width: 70,
                        height: 1.5,
                        color: const Color(0xFFD6BE88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'طيّب قلبك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      JourneyCopy.posterFindUs,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A name the reader chose to show, kept small: the poster is an invitation
/// to read, and the reader is not its subject.
class _PosterName extends StatelessWidget {
  const _PosterName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: kSans,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3E5145),
      ),
    );
  }
}

/// The reader's tree, as an invitation to read the Forty together.
class TreePoster extends StatelessWidget {
  const TreePoster({
    super.key,
    required this.format,
    required this.data,
    this.name,
  });

  final PosterFormat format;
  final JourneyData data;

  /// Null unless the reader turned their name on.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final count = data.completeCount;

    return _PosterFrame(
      format: format,
      child: Column(
        children: [
          const Text(
            JourneyCopy.posterInvitation,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              // Loaded by shareTree before the poster is built.
              painter: JourneyTreePainter(
                looks: leafLooks(data),
                art: TreeArt.ready,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${toArabicDigits(count)} من ٤٢ حديثاً',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          if (name != null) ...[
            const SizedBox(height: 2),
            _PosterName(name!),
          ],
        ],
      ),
    );
  }
}

/// The week's harvest: three numbers, the ones رحلتي shows for the week.
/// Each on its own tile with a leaf, and no comparison with anyone, so it
/// reads as an invitation. A Status has the room to stack them.
class HarvestPoster extends StatelessWidget {
  const HarvestPoster({
    super.key,
    required this.format,
    required this.harvest,
    this.weekLabel,
    this.name,
  });

  final PosterFormat format;
  final Harvest harvest;

  /// «أسبوع ١٤–٢٠ نوفمبر», when known.
  final String? weekLabel;

  /// Null unless the reader turned their name on.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final tall = format == PosterFormat.story;
    final tiles = [
      _HarvestTile(
        value: harvest.streak,
        unit: _posterDayUnit(harvest.streak),
        label: 'الاستمرارية',
        tall: tall,
      ),
      _HarvestTile(
        value: harvest.bestRun,
        unit: _posterDayUnit(harvest.bestRun),
        label: 'أفضل استمرارية',
        tall: tall,
      ),
      _HarvestTile(
        value: harvest.points,
        unit: 'نقطة',
        label: 'نقاط الأسبوع',
        tall: tall,
      ),
    ];

    return _PosterFrame(
      format: format,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'حصاد أسبوعي',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 30,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          if (weekLabel != null)
            Text(
              weekLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          SizedBox(height: tall ? 26 : 18),
          if (tall)
            for (final tile in tiles) ...[
              SizedBox(width: 250, child: tile),
              const SizedBox(height: 12),
            ]
          else
            Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          SizedBox(height: tall ? 14 : 18),
          const Text(
            JourneyCopy.posterInvitation,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          if (name != null) ...[
            const SizedBox(height: 6),
            _PosterName(name!),
          ],
        ],
      ),
    );
  }
}

/// The noun after a count of days on a poster.
String _posterDayUnit(int count) => switch (count) {
      1 => 'يوم',
      2 => 'يومان',
      >= 3 && <= 10 => 'أيام',
      _ => 'يوماً',
    };

/// One of the harvest's three numbers: a gold leaf, the figure, its unit and
/// what it counts, on a pale card.
class _HarvestTile extends StatelessWidget {
  const _HarvestTile({
    required this.value,
    required this.unit,
    required this.label,
    required this.tall,
  });

  final int value;
  final String unit;
  final String label;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final figure = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: toArabicDigits(value),
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          TextSpan(
            text: ' $unit',
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _green,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
    final caption = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      style: const TextStyle(
        fontFamily: kSans,
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: _gold,
      ),
    );
    const leaf = SizedBox(
      height: 26,
      child: LeafSwatch(LeafLook.memorized, height: 26),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: tall ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFDF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99D6BE88), width: 1.2),
      ),
      child: tall
          ? Row(
              children: [
                leaf,
                const SizedBox(width: 10),
                Expanded(child: caption),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: figure),
                ),
              ],
            )
          : Column(
              children: [
                leaf,
                const SizedBox(height: 6),
                FittedBox(fit: BoxFit.scaleDown, child: figure),
                const SizedBox(height: 2),
                caption,
              ],
            ),
    );
  }
}

/// A milestone the reader reached (5, 10, 20, 30 or 42 hadiths), in the
/// same words the completion sheet showed them. The message is the point of
/// this poster, so it takes the room.
class MilestonePoster extends StatelessWidget {
  const MilestonePoster({
    super.key,
    required this.format,
    required this.milestone,
    this.name,
  });

  final PosterFormat format;

  /// How many hadiths the reader has finished: one of the milestones.
  final int milestone;

  /// Null unless the reader turned their name on.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final message = JourneyCopy.milestone(milestone);

    return _PosterFrame(
      format: format,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // FittedBox is the real guarantee, as on ShareCard: the message
          // keeps its size where it fits, and only ever shrinks.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: format.size.width - 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 28,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kSans,
                        fontSize: 15.5,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${toArabicDigits(milestone)} من ٤٢ حديثاً',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          if (name != null) ...[
            const SizedBox(height: 6),
            _PosterName(name!),
          ],
        ],
      ),
    );
  }
}
