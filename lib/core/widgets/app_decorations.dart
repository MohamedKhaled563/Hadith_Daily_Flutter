import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppDecorations {
  // 1. Center Heart Leaf Emblem (طيّب قلبك)
  static Widget heartLeafEmblem({double size = 48}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HeartLeafEmblemPainter(),
    );
  }

  // 2. Golden Decorative Flourish Divider
  static Widget goldenDivider({double width = 80, double height = 12}) {
    return CustomPaint(
      size: Size(width, height),
      painter: _GoldenDividerPainter(),
    );
  }

  // 3. Flower Badge (used in Hadith list)
  static Widget flowerBadge({double size = 36}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FlowerBadgePainter(),
    );
  }

  // 4. Leaf Badge (used in Hadith list)
  static Widget leafBadge({double size = 36}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LeafBadgePainter(),
    );
  }

  // 5. Watercolor Botanical Branch (Top-Right)
  static Widget botanicalTopRight({double width = 120, double height = 150}) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BotanicalBranchPainter(isTopRight: true),
    );
  }

  // 6. Watercolor Botanical Branch (Bottom-Left)
  static Widget botanicalBottomLeft({double width = 120, double height = 150}) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BotanicalBranchPainter(isTopRight: false),
    );
  }

  // 7. Warm Sunset Landscape at the bottom
  static Widget sunsetLandscape({double height = 200}) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SunsetLandscapePainter(),
    );
  }
}

// ------------------- PAINTERS -------------------

class _HeartLeafEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale);

    final greenLine = Paint()
      ..color = const Color(0xFF3D5643)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final greenFill = Paint()
      ..color = const Color(0xFF5E7C65)
      ..style = PaintingStyle.fill;

    final lightGreenFill = Paint()
      ..color = const Color(0xFF7B9B82)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFC4AD78)
      ..style = PaintingStyle.fill;

    final goldStroke = Paint()
      ..color = const Color(0xFFC4AD78)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Top Dot
    canvas.drawCircle(const Offset(50, 12), 2.5, greenFill);

    // Heart Outline Outer Leaves
    final leftHeart = Path()
      ..moveTo(50, 26)
      ..cubicTo(44, 16, 28, 14, 20, 24)
      ..cubicTo(9, 36, 12, 54, 26, 68)
      ..cubicTo(36, 78, 48, 86, 50, 90);
    canvas.drawPath(leftHeart, greenLine);

    final rightHeart = Path()
      ..moveTo(50, 26)
      ..cubicTo(56, 16, 72, 14, 80, 24)
      ..cubicTo(91, 36, 88, 54, 74, 68)
      ..cubicTo(64, 78, 52, 86, 50, 90);
    canvas.drawPath(rightHeart, greenLine);

    // Inner Stem
    final stem = Path()
      ..moveTo(50, 88)
      ..cubicTo(50, 70, 50, 45, 50, 28);
    canvas.drawPath(stem, greenLine);

    // Central Top Leaf
    final centerLeaf = Path()
      ..moveTo(50, 52)
      ..cubicTo(45, 42, 46, 32, 50, 27)
      ..cubicTo(54, 32, 55, 42, 50, 52);
    canvas.drawPath(centerLeaf, greenFill);

    // Left Leaf
    final leftLeaf = Path()
      ..moveTo(50, 64)
      ..cubicTo(38, 60, 28, 48, 26, 38)
      ..cubicTo(36, 40, 45, 48, 50, 64);
    canvas.drawPath(leftLeaf, lightGreenFill);

    // Right Leaf
    final rightLeaf = Path()
      ..moveTo(50, 60)
      ..cubicTo(62, 56, 72, 44, 74, 34)
      ..cubicTo(64, 36, 55, 44, 50, 60);
    canvas.drawPath(rightLeaf, greenFill);

    // Bottom Gold Flourish
    canvas.drawCircle(const Offset(50, 93), 2.2, goldPaint);
    canvas.drawCircle(const Offset(42, 91), 1.5, goldPaint);
    canvas.drawCircle(const Offset(58, 91), 1.5, goldPaint);

    final goldSwirl = Path()
      ..moveTo(40, 91)
      ..cubicTo(32, 90, 24, 88, 18, 90)
      ..moveTo(60, 91)
      ..cubicTo(68, 90, 76, 88, 82, 90);
    canvas.drawPath(goldSwirl, goldStroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldenDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final goldLine = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x00C4AD78),
          Color(0xFFC4AD78),
          Color(0xFFE2D0A5),
          Color(0xFFC4AD78),
          Color(0x00C4AD78),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final goldFill = Paint()
      ..color = const Color(0xFFC4AD78)
      ..style = PaintingStyle.fill;

    final greenLeaf = Paint()
      ..color = const Color(0xFF5E7C65)
      ..style = PaintingStyle.fill;

    // Ribbons
    final leftRibbon = Path()
      ..moveTo(0, cy)
      ..cubicTo(cx * 0.3, cy - 3, cx * 0.7, cy + 3, cx - 12, cy);
    canvas.drawPath(leftRibbon, goldLine);

    final rightRibbon = Path()
      ..moveTo(size.width, cy)
      ..cubicTo(size.width - cx * 0.3, cy - 3, size.width - cx * 0.7, cy + 3, cx + 12, cy);
    canvas.drawPath(rightRibbon, goldLine);

    // Center Gold Bud
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 7, height: 11),
      goldFill,
    );

    // Center Left & Right Petite Leaves
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 7, cy), width: 6, height: 4),
      greenLeaf,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 7, cy), width: 6, height: 4),
      greenLeaf,
    );

    // Accent Dots
    canvas.drawCircle(Offset(cx - 16, cy), 1.5, goldFill);
    canvas.drawCircle(Offset(cx + 16, cy), 1.5, goldFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlowerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bgPaint = Paint()..color = const Color(0xFFF4EEE3);
    canvas.drawCircle(Offset(cx, cy), size.width / 2, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFD1BE93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), size.width / 2 - 0.5, borderPaint);

    final petalPaint = Paint()..color = const Color(0xFF526B57);
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final px = cx + math.cos(angle) * (size.width * 0.22);
      final py = cy + math.sin(angle) * (size.width * 0.22);
      canvas.drawCircle(Offset(px, py), size.width * 0.14, petalPaint);
    }

    final centerPaint = Paint()..color = const Color(0xFFB9A06A);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.13, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeafBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bgPaint = Paint()..color = const Color(0xFFF4EEE3);
    canvas.drawCircle(Offset(cx, cy), size.width / 2, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFD1BE93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), size.width / 2 - 0.5, borderPaint);

    final leafPaint = Paint()..color = const Color(0xFF526B57);
    final path = Path()
      ..moveTo(cx - 8, cy + 8)
      ..cubicTo(cx - 10, cy - 2, cx - 2, cy - 10, cx + 8, cy - 8)
      ..cubicTo(cx + 10, cy + 2, cx + 2, cy + 10, cx - 8, cy + 8);
    canvas.drawPath(path, leafPaint);

    final stemPaint = Paint()
      ..color = const Color(0xFFB9A06A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 9, cy + 9), Offset(cx + 7, cy - 7), stemPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BotanicalBranchPainter extends CustomPainter {
  final bool isTopRight;

  _BotanicalBranchPainter({required this.isTopRight});

  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = const Color(0x754A6B53)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafDark = Paint()
      ..color = const Color(0x60526B57)
      ..style = PaintingStyle.fill;

    final leafSoft = Paint()
      ..color = const Color(0x507D8F78)
      ..style = PaintingStyle.fill;

    final goldBud = Paint()
      ..color = const Color(0x70C4AD78)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isTopRight) {
      // Branch from top-right corner curving inward
      path.moveTo(size.width + 10, -5);
      path.cubicTo(size.width * 0.7, size.height * 0.3, size.width * 0.4, size.height * 0.6, size.width * 0.15, size.height * 0.95);
      canvas.drawPath(path, stemPaint);

      // Leaves along the branch
      _drawLeaf(canvas, Offset(size.width * 0.75, size.height * 0.2), 22, 12, -0.6, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.85, size.height * 0.28), 18, 10, 0.4, leafSoft);
      _drawLeaf(canvas, Offset(size.width * 0.55, size.height * 0.45), 24, 13, -0.7, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.45, size.height * 0.55), 18, 10, 0.5, leafSoft);
      _drawLeaf(canvas, Offset(size.width * 0.25, size.height * 0.8), 20, 11, -0.5, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.15, size.height * 0.95), 14, 8, -0.8, goldBud);
    } else {
      // Branch from bottom-left corner curving upward
      path.moveTo(-10, size.height + 5);
      path.cubicTo(size.width * 0.3, size.height * 0.7, size.width * 0.6, size.height * 0.4, size.width * 0.85, size.height * 0.05);
      canvas.drawPath(path, stemPaint);

      // Leaves along the branch
      _drawLeaf(canvas, Offset(size.width * 0.25, size.height * 0.8), 22, 12, 0.6, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.15, size.height * 0.72), 18, 10, -0.4, leafSoft);
      _drawLeaf(canvas, Offset(size.width * 0.45, size.height * 0.55), 24, 13, 0.7, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.55, size.height * 0.45), 18, 10, -0.5, leafSoft);
      _drawLeaf(canvas, Offset(size.width * 0.75, size.height * 0.2), 20, 11, 0.5, leafDark);
      _drawLeaf(canvas, Offset(size.width * 0.85, size.height * 0.05), 14, 8, 0.8, goldBud);
    }
  }

  void _drawLeaf(Canvas canvas, Offset center, double w, double h, double rotation, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SunsetLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing warm sun on the horizon
    final sunCenter = Offset(w * 0.5, h * 0.45);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x60F8D295),
          const Color(0x35F1BC78),
          const Color(0x00F8F3EA),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 110));
    canvas.drawCircle(sunCenter, 110, sunPaint);

    // Distant soft hill layer 1
    final hill1 = Path()
      ..moveTo(0, h * 0.6)
      ..cubicTo(w * 0.25, h * 0.52, w * 0.4, h * 0.62, w * 0.65, h * 0.54)
      ..cubicTo(w * 0.85, h * 0.48, w * 0.95, h * 0.55, w, h * 0.58)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final hill1Paint = Paint()..color = const Color(0x28C4B598);
    canvas.drawPath(hill1, hill1Paint);

    // Mid hill layer 2
    final hill2 = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.2, h * 0.65, w * 0.45, h * 0.75, w * 0.7, h * 0.66)
      ..cubicTo(w * 0.88, h * 0.60, w * 0.95, h * 0.68, w, h * 0.7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final hill2Paint = Paint()..color = const Color(0x389CAE96);
    canvas.drawPath(hill2, hill2Paint);

    // Foreground soft lush hill layer 3
    final hill3 = Path()
      ..moveTo(0, h * 0.84)
      ..cubicTo(w * 0.3, h * 0.78, w * 0.6, h * 0.86, w, h * 0.8)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final hill3Paint = Paint()..color = const Color(0x45526B57);
    canvas.drawPath(hill3, hill3Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
