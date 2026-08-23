import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic Traditional Islamic Geometric Arabesque Watermark Pattern
/// Draws an intricate 8-pointed star rosette (Shamsah medallion) with interlacing geometric petals and embossed relief
class IslamicWatermarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  IslamicWatermarkPainter({
    this.color = const Color(0x30B89F70),
    this.strokeWidth = 1.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;

    if (radius <= 0) return;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final subtleFillPaint = Paint()
      ..color = color.withOpacity(color.opacity * 0.22)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Outer Concentric Ring
    canvas.drawCircle(center, radius, linePaint);
    canvas.drawCircle(center, radius * 0.78, linePaint);
    canvas.drawCircle(center, radius * 0.48, linePaint);
    canvas.drawCircle(center, radius * 0.22, subtleFillPaint);
    canvas.drawCircle(center, radius * 0.22, linePaint);

    // 2. 8-Pointed Star (Octagram / 8-pointed Girih star)
    final double squareSize = radius * 1.38;
    _drawRotatedSquare(canvas, center, squareSize, 0, linePaint);
    _drawRotatedSquare(canvas, center, squareSize, math.pi / 4, linePaint);

    // 3. 8 Curved Interlaced Petals
    const int points = 8;
    for (int i = 0; i < points; i++) {
      final double angle = (i * 2 * math.pi) / points;
      final double nextAngle = ((i + 1) * 2 * math.pi) / points;
      final double midAngle = (angle + nextAngle) / 2;

      // Outer Star Tip
      final tip = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Inner Valley
      final innerValley = Offset(
        center.dx + (radius * 0.52) * math.cos(midAngle),
        center.dy + (radius * 0.52) * math.sin(midAngle),
      );

      // Core Node
      final coreNode = Offset(
        center.dx + (radius * 0.26) * math.cos(angle),
        center.dy + (radius * 0.26) * math.sin(angle),
      );

      // Draw Diamond rosette facet
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(innerValley.dx, innerValley.dy)
        ..lineTo(coreNode.dx, coreNode.dy);
      canvas.drawPath(path, linePaint);

      // Intersecting petal arc
      final petalArc = Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(
          center.dx + (radius * 0.7) * math.cos(midAngle),
          center.dy + (radius * 0.7) * math.sin(midAngle),
          center.dx + (radius * 0.32) * math.cos(nextAngle),
          center.dy + (radius * 0.32) * math.sin(nextAngle),
        );
      canvas.drawPath(petalArc, linePaint);

      // Decorative mini node at each star tip
      canvas.drawCircle(tip, 1.6, linePaint);
    }
  }

  void _drawRotatedSquare(
      Canvas canvas, Offset center, double size, double rotation, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IslamicWatermarkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
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
