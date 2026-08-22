import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'asset_helper.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showBottomLandscape;

  const AppBackground({
    super.key,
    required this.child,
    this.showBottomLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Base Color
          const ColoredBox(
            color: AppColors.background,
          ),

          // Bottom Sunset Landscape (if enabled)
          if (showBottomLandscape)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 220,
              child: IgnorePointer(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/sunset_landscape.svg',
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),

          // Top-right botanical watercolor decoration
          Positioned(
            top: 0,
            right: 0,
            width: 130,
            height: 160,
            child: IgnorePointer(
              child: AssetHelper.assetOrFallback(
                assetPath: 'assets/images/botanical_top_right.svg',
                width: 130,
                height: 160,
                fit: BoxFit.contain,
                fallback: CustomPaint(
                  size: const Size(130, 160),
                  painter: _BotanicalPainter(isTopRight: true),
                ),
              ),
            ),
          ),

          // Bottom-left botanical watercolor decoration
          Positioned(
            bottom: 0,
            left: 0,
            width: 130,
            height: 160,
            child: IgnorePointer(
              child: AssetHelper.assetOrFallback(
                assetPath: 'assets/images/botanical_bottom_left.svg',
                width: 130,
                height: 160,
                fit: BoxFit.contain,
                fallback: CustomPaint(
                  size: const Size(130, 160),
                  painter: _BotanicalPainter(isTopRight: false),
                ),
              ),
            ),
          ),

          // Safe area child
          SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  final bool isTopRight;

  _BotanicalPainter({required this.isTopRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondaryGreen.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = AppColors.primaryGreen.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTopRight) {
      path.moveTo(size.width, 0);
      path.quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.2, size.height * 0.9);
      canvas.drawPath(path, stemPaint);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.7, size.height * 0.25), width: 22, height: 12),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.45, size.height * 0.45), width: 20, height: 10),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.25, size.height * 0.8), width: 18, height: 9),
        paint,
      );
    } else {
      path.moveTo(0, size.height);
      path.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.8, size.height * 0.3);
      canvas.drawPath(path, stemPaint);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.3, size.height * 0.75), width: 22, height: 12),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.55, size.height * 0.55), width: 20, height: 10),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.75, size.height * 0.35), width: 18, height: 9),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
