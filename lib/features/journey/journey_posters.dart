import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/icon_badge.dart';
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

/// One of a poster's numbers: the mark it wears on رحلتي, the figure, its
/// unit and what it counts.
class PosterFigure {
  const PosterFigure({
    required this.value,
    required this.unit,
    required this.label,
    this.icon,
    this.tone = BadgeTone.gold,
  });

  final String value;
  final String unit;
  final String label;

  /// Null for the gold leaf of a memorized hadith.
  final IconData? icon;
  final BadgeTone tone;
}

/// The week's harvest: three numbers, the ones رحلتي shows for the week,
/// each with the mark it has there. No comparison with anyone, so it reads
/// as an invitation. A Status has the room to stack them.
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
    return _NumbersPoster(
      format: format,
      title: 'حصاد أسبوعي',
      subtitle: weekLabel,
      name: name,
      figures: [
        PosterFigure(
          icon: Icons.local_fire_department_rounded,
          tone: BadgeTone.warm,
          value: toArabicDigits(harvest.streak),
          unit: _posterDayUnit(harvest.streak),
          label: 'الاستمرارية',
        ),
        PosterFigure(
          icon: Icons.workspace_premium_rounded,
          tone: BadgeTone.green,
          value: toArabicDigits(harvest.bestRun),
          unit: _posterDayUnit(harvest.bestRun),
          label: 'أفضل استمرارية',
        ),
        PosterFigure(
          icon: Icons.star_rounded,
          value: toArabicDigits(harvest.points),
          unit: 'نقطة',
          label: 'نقاط الأسبوع',
        ),
      ],
    );
  }
}

/// The whole journey's harvest: the three numbers under «حصاد رحلتك».
class JourneyHarvestPoster extends StatelessWidget {
  const JourneyHarvestPoster({
    super.key,
    required this.format,
    required this.bestStreak,
    required this.points,
    required this.memorized,
    this.name,
  });

  final PosterFormat format;
  final int bestStreak;
  final int points;
  final int memorized;

  /// Null unless the reader turned their name on.
  final String? name;

  @override
  Widget build(BuildContext context) {
    return _NumbersPoster(
      format: format,
      title: 'حصاد رحلتي',
      subtitle: 'مع الأربعين النووية',
      name: name,
      figures: [
        PosterFigure(
          icon: Icons.emoji_events_rounded,
          value: toArabicDigits(bestStreak),
          unit: _posterDayUnit(bestStreak),
          label: 'أفضل استمرارية',
        ),
        PosterFigure(
          icon: Icons.stars_rounded,
          value: toArabicDigits(points),
          unit: 'نقطة',
          label: 'كل نقاطي',
        ),
        PosterFigure(
          value: '${toArabicDigits(memorized)} / ٤٢',
          unit: 'حديثاً',
          label: 'حفظت',
        ),
      ],
    );
  }
}

/// Three numbers on the light poster ground, under a title.
class _NumbersPoster extends StatelessWidget {
  const _NumbersPoster({
    required this.format,
    required this.title,
    required this.figures,
    this.subtitle,
    this.name,
  });

  final PosterFormat format;
  final String title;
  final String? subtitle;
  final List<PosterFigure> figures;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final tall = format == PosterFormat.story;
    final tiles = [
      for (final figure in figures) _FigureTile(figure: figure, tall: tall),
    ];

    return _PosterFrame(
      format: format,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 30,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          SizedBox(height: tall ? 26 : 14),
          if (tall)
            for (final tile in tiles) ...[
              SizedBox(width: 250, child: tile),
              const SizedBox(height: 12),
            ]
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
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

/// One number on a pale card: its badge, as on رحلتي, the figure with its
/// unit, and what it counts.
class _FigureTile extends StatelessWidget {
  const _FigureTile({required this.figure, required this.tall});

  final PosterFigure figure;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: figure.value,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          TextSpan(
            text: ' ${figure.unit}',
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
      figure.label,
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
    final badge = IconBadge(
      palette: BotanicalPalette.light,
      icon: figure.icon,
      tone: figure.tone,
      size: tall ? 36 : 30,
      child: figure.icon == null
          ? const LeafSwatch(LeafLook.memorized, height: 20)
          : null,
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
                badge,
                const SizedBox(width: 10),
                Expanded(child: caption),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: text),
                ),
              ],
            )
          : Column(
              children: [
                badge,
                const SizedBox(height: 6),
                FittedBox(fit: BoxFit.scaleDown, child: text),
                const SizedBox(height: 2),
                caption,
              ],
            ),
    );
  }
}

/// One name on the board's poster.
class PosterBoardRow {
  const PosterBoardRow({required this.name, this.value});

  final String name;

  /// What the name scored, as the board shows it; null on the memorizing
  /// list, which shows names only.
  final String? value;
}

/// The weekly board as a poster: an honour roll, emerald under gold, so it
/// looks like nothing else the app sends. Names only, as the board shows
/// them to everyone; the reader's own name is not singled out.
class BoardPoster extends StatelessWidget {
  const BoardPoster({
    super.key,
    required this.format,
    required this.weekLabel,
    required this.listLabel,
    required this.rows,
  });

  final PosterFormat format;

  /// «أسبوع ٧ – ١٣ نوفمبر».
  final String weekLabel;

  /// Which list: «النقاط», «المشاركة» or «الحفظ».
  final String listLabel;
  final List<PosterBoardRow> rows;

  static const _emeraldTop = Color(0xFF2A4A37);
  static const _emerald = Color(0xFF1E2E24);
  static const _emeraldDeep = Color(0xFF13211A);
  static const _goldBright = Color(0xFFD9A521);
  static const _goldPale = Color(0xFFF0D88E);
  static const _cream = Color(0xFFF7F1E2);
  static const _creamSoft = Color(0xFFCFDDD3);
  static const _medals = [
    Color(0xFFD9A521),
    Color(0xFFA7ADB4),
    Color(0xFFB87333),
  ];

  @override
  Widget build(BuildContext context) {
    final tall = format == PosterFormat.story;
    final shown = rows.take(10).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox.fromSize(
        size: format.size,
        child: Material(
          color: _emerald,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_emeraldTop, _emerald, _emeraldDeep],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicWatermarkPainter(
                    color: const Color(0x26D9A521),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Opacity(
                  opacity: 0.30,
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
                  opacity: 0.30,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.png',
                    width: 96,
                    height: 108,
                  ),
                ),
              ),
              // A double gold frame, like a certificate.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _goldBright, width: 1.6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0x66D9A521)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(30, tall ? 40 : 28, 30, 24),
                child: Column(
                  children: [
                    Container(
                      width: tall ? 52 : 40,
                      height: tall ? 52 : 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-.35, -.45),
                          colors: [_goldPale, _goldBright, Color(0xFFB0841A)],
                          stops: [0, .6, 1],
                        ),
                        border: Border.all(color: const Color(0xFF8A6713)),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        size: tall ? 28 : 22,
                        color: _emerald,
                      ),
                    ),
                    SizedBox(height: tall ? 10 : 6),
                    Text(
                      'لوحة الأسبوع',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: tall ? 32 : 26,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: _goldPale,
                      ),
                    ),
                    Text(
                      weekLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kSans,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: _creamSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Which list, on a chip of its own: a dot between it and
                    // the dates reads as an Arabic zero.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0x99D9A521)),
                        color: const Color(0x1FD9A521),
                      ),
                      child: Text(
                        listLabel,
                        style: const TextStyle(
                          fontFamily: kSans,
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                          color: _goldPale,
                        ),
                      ),
                    ),
                    SizedBox(height: tall ? 18 : 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: format.size.width - 60,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (i, row) in shown.indexed)
                                _boardRow(i + 1, row, tall),
                            ],
                          ),
                        ),
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
                        color: _goldPale,
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
                        color: _creamSoft,
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

  Widget _boardRow(int rank, PosterBoardRow row, bool tall) {
    final medal = rank <= 3 ? _medals[rank - 1] : null;
    final height = tall ? 38.0 : 30.0;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: medal == null
            ? const Color(0x0FFFFFFF)
            : medal.withValues(alpha: .16),
        border: Border.all(
          color: medal == null
              ? const Color(0x22F0D88E)
              : medal.withValues(alpha: .55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: height - 8,
            height: height - 8,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal,
              border: Border.all(
                color: medal == null ? const Color(0x88F0D88E) : _emeraldDeep,
              ),
            ),
            child: Text(
              toArabicDigits(rank),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: tall ? 14 : 12,
                height: 1,
                fontWeight: FontWeight.w800,
                color: medal == null ? _goldPale : _emerald,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: tall ? 15.5 : 13.5,
                height: 1.2,
                fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                color: _cream,
              ),
            ),
          ),
          if (row.value != null)
            Text(
              row.value!,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: tall ? 14 : 12.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: _goldPale,
              ),
            ),
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
