import 'package:flutter/material.dart';

/// Ultra-smooth, professional page route that transitions gracefully
/// with scale, fade, and elevation without any background bleed-through or overlaps.
class SeamlessMessagePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SeamlessMessagePageRoute({required this.child})
      : super(
          opaque: true, // Guarantees crisp rendering with zero background double-render or text overlap
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOutCubic;
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: Curves.easeInCubic,
            );

            // 1. Soft, graceful fade
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
              ),
            );

            // 2. Subtle, natural scale expansion
            final scaleAnimation = Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(curvedAnimation);

            // 3. Gentle upward bloom
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.025),
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
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOutCubic;
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.85, curve: curve)),
            );
            final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.02),
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
