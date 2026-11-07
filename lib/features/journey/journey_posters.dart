import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/journey_points.dart';
import '../../data/models/hadith.dart';
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
    final colors = TreeColors.poster();

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
              painter: JourneyTreePainter(
                looks: leafLooks(data),
                colors: colors,
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

/// The week's harvest: how many days and minutes went to the hadith. Small
/// numbers, and no comparison with anyone, so it reads as an invitation.
class HarvestPoster extends StatelessWidget {
  const HarvestPoster({
    super.key,
    required this.format,
    required this.harvest,
    this.name,
  });

  final PosterFormat format;
  final Harvest harvest;

  /// Null unless the reader turned their name on.
  final String? name;

  @override
  Widget build(BuildContext context) {
    return _PosterFrame(
      format: format,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            JourneyCopy.harvestInvitation,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            arabicDayCount(harvest.days),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 40,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'و${arabicMinuteCount(harvest.minutes)} مع الحديث',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'من الأربعين النووية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
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

/// The hadith just finished. The hadith is the point of this poster, so it
/// takes the room, and the reader's progress does not appear at all.
class HadithPoster extends StatelessWidget {
  const HadithPoster({
    super.key,
    required this.format,
    required this.hadith,
    this.name,
  });

  final PosterFormat format;
  final Hadith hadith;

  /// Null unless the reader turned their name on.
  final String? name;

  double get _titleSize {
    final length = hadith.title.characters.length;
    if (length <= 18) return 38;
    if (length <= 30) return 30;
    return 25;
  }

  @override
  Widget build(BuildContext context) {
    return _PosterFrame(
      format: format,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            JourneyCopy.posterReadToday,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          const SizedBox(height: 16),
          // FittedBox is the real guarantee, as on ShareCard: the sizes above
          // are an estimate of how a title wraps, and this only ever shrinks.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: format.size.width - 60,
                child: Text(
                  hadith.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: _titleSize,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'الحديث ${toArabicDigits(hadith.number)} من الأربعين النووية',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kSans,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
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
