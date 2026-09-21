import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Whether this build should use Cupertino page transitions.
///
/// Both of the app's custom routes are [PageRouteBuilder]s, which means they
/// bypass `pageTransitionsTheme` *and* the interactive pop gesture that comes
/// with [CupertinoRouteTransitionMixin] — so on iOS the edge-swipe back, which
/// is how iOS users navigate, did not work anywhere in the app.
///
/// A conditional mixin is not a thing in Dart, so the choice is made per route
/// instead: iOS gets a real Cupertino route (native slide, native swipe-back),
/// everything else keeps the app's own fade-and-rise. Guarded against the web
/// build, where `Platform` throws.
bool get _useCupertino =>
    !kIsWeb && (Platform.isIOS || Platform.isMacOS);

/// A page route that behaves like the platform expects.
///
/// Use this rather than constructing either class below directly.
PageRoute<T> appPageRoute<T>({required Widget child}) => _useCupertino
    ? CupertinoPageRoute<T>(builder: (_) => child)
    : _SmoothPageRoute<T>(child: child);

/// The message card's route, which carries a Hero flight from the home
/// circle. Same platform split, for the same reason.
///
/// [settings] is optional and only used where a caller needs to recognise
/// its own route later — main.dart names the tapped-reminder message route
/// so a second notification tap can tell it is already open rather than
/// stacking a duplicate.
PageRoute<T> appMessageRoute<T>({
  required Widget child,
  RouteSettings? settings,
}) =>
    _useCupertino
        ? CupertinoPageRoute<T>(builder: (_) => child, settings: settings)
        : _SeamlessMessagePageRoute<T>(child: child, settings: settings);


/// Ultra-smooth, professional page route that transitions gracefully
/// with scale, fade, and elevation without any background bleed-through or overlaps.
class _SeamlessMessagePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  _SeamlessMessagePageRoute({required this.child, super.settings})
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
class _SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  _SmoothPageRoute({required this.child})
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
