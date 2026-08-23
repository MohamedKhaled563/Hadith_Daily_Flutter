import 'package:flutter/material.dart';

/// Ultra-smooth, professional page route that preserves background continuity
/// and provides a luxury shared-axis scale, fade, and elevation transition.
class SeamlessMessagePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SeamlessMessagePageRoute({required this.child})
      : super(
          opaque: false, // Allows seamless background continuity without flashes
          barrierColor: Colors.black.withOpacity(0.04),
          transitionDuration: const Duration(milliseconds: 440),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // High-end fluid easing curve (Apple / Material 3 Fluid Easing)
            const forwardCurve = Curves.easeOutCubic;
            const reverseCurve = Curves.easeInCubic;

            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: forwardCurve,
              reverseCurve: reverseCurve,
            );

            // 1. Soft, graceful fade
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
              ),
            );

            // 2. Subtle, natural scale expansion (from 0.92 to 1.0)
            final scaleAnimation = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(curvedAnimation);

            // 3. Gentle upward bloom
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation);

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// General purpose smooth page route with seamless curves
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SmoothPageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOutCubic;
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.85, curve: curve)),
            );
            final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}
