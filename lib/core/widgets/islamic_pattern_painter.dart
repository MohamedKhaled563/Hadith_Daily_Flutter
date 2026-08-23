import 'dart:math' as math;
import 'package:flutter/material.dart';

class IslamicWatermarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  IslamicWatermarkPainter({
    this.color = const Color(0x12D1BE93),
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    if (radius <= 0) return;

    // Draw Outer decorative circles
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.72, paint);
    canvas.drawCircle(center, radius * 0.35, paint);

    // Draw 8-pointed Islamic Star rosette
    final int points = 8;
    for (int i = 0; i < points; i++) {
      final double angle1 = (i * 2 * math.pi) / points;
      final double angle2 = ((i + 1) * 2 * math.pi) / points;
      final double midAngle = (angle1 + angle2) / 2;

      final p1 = Offset(
        center.dx + radius * math.cos(angle1),
        center.dy + radius * math.sin(angle1),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle2),
        center.dy + radius * math.sin(angle2),
      );
      final innerP = Offset(
        center.dx + (radius * 0.52) * math.cos(midAngle),
        center.dy + (radius * 0.52) * math.sin(midAngle),
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(innerP.dx, innerP.dy)
        ..lineTo(p2.dx, p2.dy);
      canvas.drawPath(path, paint);

      // Connect to inner circle for interlacing effect
      final innermostP = Offset(
        center.dx + (radius * 0.22) * math.cos(midAngle),
        center.dy + (radius * 0.22) * math.sin(midAngle),
      );
      canvas.drawLine(innerP, innermostP, paint);
    }

    // Intersecting 8-fold square overlay
    _drawRotatedSquare(canvas, center, radius * 0.85, 0, paint);
    _drawRotatedSquare(canvas, center, radius * 0.85, math.pi / 4, paint);
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
