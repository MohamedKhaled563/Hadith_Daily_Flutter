import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/asset_helper.dart';
import '../widgets/islamic_pattern_painter.dart';

/// The poster rendered to an image when a reader shares a message.
///
/// This is laid out for a social feed, not for the app: a fixed 1080×1350
/// canvas (the 4:5 portrait that WhatsApp, Instagram and Facebook all crop
/// least aggressively) with type sized for a thumbnail rather than a phone
/// held at reading distance.
///
/// It is built at a logical size of [width]×[height] and captured at a pixel
/// ratio that produces those final dimensions — see `ShareCardRenderer`.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.message,
    this.hadithTitle,
    this.hadithNumber,
    this.attribution,
    this.category,
  });

  /// The text being shared — a daily message, or a community reflection.
  final String message;

  final String? hadithTitle;
  final String? hadithNumber;

  /// Who wrote it, for community posts. Null for app messages.
  final String? attribution;

  final String? category;

  /// Logical canvas. Captured at 3× for a 1080×1350 image.
  static const double width = 360;
  static const double height = 450;

  /// Step the type down as the message grows, so the card is always well set
  /// rather than either sparse or overflowing.
  double get _messageSize {
    final length = message.characters.length;
    if (length <= 70) return 24;
    if (length <= 130) return 20;
    if (length <= 220) return 17;
    if (length <= 340) return 15;
    return 13;
  }

  @override
  Widget build(BuildContext context) {
    // Self-contained: the card cannot inherit from the app's theme because it
    // is rendered off-stage, and it should look the same whichever mode the
    // reader happens to be in. Always the light, warm treatment.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: const Color(0xFFF2ECE0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Parchment ground.
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

              // Tonal depth, matching the in-app cards.
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicWatermarkPainter(
                    color: const Color(0x22B89F70),
                  ),
                ),
              ),

              // Botanical corners, physical placement.
              Positioned(
                top: -6,
                right: -6,
                child: Opacity(
                  opacity: 0.65,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_top_right.png',
                    width: 118,
                    height: 132,
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                left: -6,
                child: Opacity(
                  opacity: 0.65,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.png',
                    width: 118,
                    height: 132,
                  ),
                ),
              ),

              // Gold rule just inside the edge.
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
                padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.png',
                      width: 46,
                      height: 46,
                      fallback: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primaryGreen,
                        size: 34,
                      ),
                    ),

                    if (category != null && category!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF6EE),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x66B89F70)),
                        ),
                        child: Text(
                          category!,
                          style: const TextStyle(
                            fontFamily: kSans,
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7A5B0E),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const _Divider(),
                    const SizedBox(height: 18),

                    // The message itself, given the room it deserves. Type is
                    // scaled to length so a short line fills the canvas
                    // instead of floating in it, and a long one still fits.
                    Flexible(
                      child: Center(
                        child: Text(
                          '« $message »',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: _messageSize,
                            height: 1.8,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF243329),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const _Divider(),
                    const SizedBox(height: 14),

                    if (attribution != null && attribution!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '✍️ ${attribution!}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kSans,
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3E5145),
                          ),
                        ),
                      ),

                    if (hadithTitle != null && hadithTitle!.trim().isNotEmpty)
                      Text(
                        hadithNumber == null
                            ? hadithTitle!
                            : 'الحديث $hadithNumber: ${hadithTitle!}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kSans,
                          fontSize: 11.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A5B0E),
                        ),
                      ),

                    const SizedBox(height: 12),

                    const Text(
                      '🌿 طيّب قلبك • الأربعين النووية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A7061),
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return AssetHelper.assetOrFallback(
      assetPath: 'assets/images/golden_divider.png',
      width: 120,
      height: 15,
      fallback: Container(
        width: 80,
        height: 1.5,
        color: const Color(0xFFD6BE88),
      ),
    );
  }
}
