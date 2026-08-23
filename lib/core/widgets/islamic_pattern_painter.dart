import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic Traditional Islamic Geometric Arabesque Watermark Pattern
/// Draws an intricate 8-pointed star rosette with interlacing geometric petals and nodes
class IslamicWatermarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  IslamicWatermarkPainter({
    this.color = const Color(0x35B89F70),
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.48;

    if (radius <= 0) return;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final subtleFillPaint = Paint()
      ..color = color.withOpacity(color.opacity * 0.25)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Concentric Guide Circles
    canvas.drawCircle(center, radius, linePaint);
    canvas.drawCircle(center, radius * 0.76, linePaint);
    canvas.drawCircle(center, radius * 0.46, linePaint);
    canvas.drawCircle(center, radius * 0.18, subtleFillPaint);
    canvas.drawCircle(center, radius * 0.18, linePaint);

    // 2. 8-Pointed Star (Octagram) formed by two overlapping 45-degree squares
    final double squareSize = radius * 1.42;
    _drawRotatedSquare(canvas, center, squareSize, 0, linePaint);
    _drawRotatedSquare(canvas, center, squareSize, math.pi / 4, linePaint);

    // 3. Intersecting Petal Arcs (Girih floral interlacing)
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
        center.dx + (radius * 0.54) * math.cos(midAngle),
        center.dy + (radius * 0.54) * math.sin(midAngle),
      );

      // Core Node
      final coreNode = Offset(
        center.dx + (radius * 0.28) * math.cos(angle),
        center.dy + (radius * 0.28) * math.sin(angle),
      );

      // Draw Diamond rosette facet
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(innerValley.dx, innerValley.dy)
        ..lineTo(coreNode.dx, coreNode.dy);
      canvas.drawPath(path, linePaint);

      // Decorative mini node at each star tip
      canvas.drawCircle(tip, 1.8, linePaint);
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
