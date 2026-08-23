import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tonal depth for a parchment card: a warm vellum vignette, plus one soft
/// eight-point star bloom set away from the centre.
///
/// Every earlier version of this drew the motif in *strokes*. Hairlines behind
/// running text fight the text however faint they are — straight edges cut
/// across Arabic letterforms and the eye keeps resolving them as lines rather
/// than as ground. Real paper reads calm because of tone, not line work, so
/// this paints no outlines at all: soft filled shapes only, blurred past the
/// point where an edge is legible.
class IslamicWatermarkPainter extends CustomPainter {
  IslamicWatermarkPainter({
    this.color = const Color(0x30B89F70),
    this.strokeWidth = 1.1,
  });

  /// Tint for both the vignette and the star bloom.
  final Color color;

  /// Retained for call-site compatibility; nothing is stroked any more.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 8) return;

    final bounds = Offset.zero & size;

    // 1. Vellum vignette — barely-there warmth gathering at the edges, so the
    //    card centre reads as slightly lifted, the way held paper does.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: color.a * 0.45),
            color.withValues(alpha: color.a * 1.15),
          ],
          stops: const [0.45, 0.82, 1.0],
        ).createShader(bounds)
        ..isAntiAlias = true,
    );

    // 2. A single eight-point star, filled and blurred, tucked toward the top
    //    corner rather than sitting behind the text block.
    final radius = size.shortestSide * 0.42;
    if (radius <= 6) return;

    final centre = Offset(size.width * 0.80, size.height * 0.20);
    final blur = radius * 0.18;

    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawPath(
      _eightPointStar(centre, radius),
      Paint()
        ..color = color.withValues(alpha: color.a * 0.85)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  /// Eight-point star as a filled polygon, alternating outer and inner radius.
  Path _eightPointStar(Offset centre, double outer) {
    const points = 8;
    final inner = outer * 0.56;
    final path = Path();

    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      // Start at -90° so a point sits at the top.
      final angle = (i * math.pi / points) - math.pi / 2;
      final p = Offset(
        centre.dx + r * math.cos(angle),
        centre.dy + r * math.sin(angle),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }

    return path..close();
  }

  @override
  bool shouldRepaint(covariant IslamicWatermarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Painter for traditional subtle gold corner brackets inside parchment cards
class CornerOrnamentPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double inset;
  final double length;

  CornerOrnamentPainter({
    required this.color,
    this.strokeWidth = 1.2,
    this.inset = 12.0,
    this.length = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Top-Left
    canvas.drawLine(Offset(inset, inset + length), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + length, inset), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - inset - length, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + length), paint);

    // Bottom-Left
    canvas.drawLine(Offset(inset, size.height - inset - length), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + length, size.height - inset), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - inset - length, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - length), paint);
  }

  @override
  bool shouldRepaint(covariant CornerOrnamentPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.inset != inset ||
      oldDelegate.length != length;
}
