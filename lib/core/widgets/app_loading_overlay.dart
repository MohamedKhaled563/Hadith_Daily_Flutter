import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';
import 'asset_helper.dart';

/// Full-screen loading notice in the app's own botanical language, for any
/// async operation (signing in, creating an account, ...) that should block
/// interaction while it runs rather than leave the reader guessing.
///
/// Wrap a screen's body with it and toggle [visible]; the screen underneath
/// stays mounted and simply gets a blurred, non-interactive scrim on top, so
/// no navigation or state is lost while it shows. Visually this is a
/// miniature of the splash screen's own emblem treatment (rotating halo +
/// breathing glow + heartbeat pulse), so a loading moment reads as the same
/// app pausing to breathe rather than a generic spinner.
///
/// For an action that isn't already tracked by a screen's own `setState`
/// (e.g. a one-off async step triggered from a bottom sheet that has already
/// closed), use [showAppLoadingOverlay]/[hideAppLoadingOverlay] instead —
/// same visual, shown imperatively over whatever is currently on screen.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message = 'جارٍ التحميل…',
  });

  final bool visible;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: IgnorePointer(
              // Absorbs taps meant for whatever is underneath rather than
              // just visually covering it.
              ignoring: false,
              child: _LoadingScrim(message: message),
            ),
          ),
      ],
    );
  }
}

/// Imperative form of [AppLoadingOverlay], for async steps that aren't owned
/// by a single screen's state — e.g. rendering a share image after the sheet
/// that triggered it has already closed. Call [hideAppLoadingOverlay] (or let
/// the same [key] be shown again) once the work finishes; an overlay left
/// showing past its screen's lifetime is a bug, not a style choice.
void showAppLoadingOverlay(
  BuildContext context, {
  String message = 'جارٍ التحميل…',
  Object key = _defaultOverlayKey,
}) {
  hideAppLoadingOverlay(key: key);
  final overlayState = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => _LoadingScrim(message: message),
  );
  _activeOverlays[key] = entry;
  overlayState.insert(entry);
}

/// Removes the overlay started by [showAppLoadingOverlay] with the same
/// [key]. Safe to call even if nothing is showing.
void hideAppLoadingOverlay({Object key = _defaultOverlayKey}) {
  _activeOverlays.remove(key)?.remove();
}

const _defaultOverlayKey = #appLoadingOverlay;
final Map<Object, OverlayEntry> _activeOverlays = {};

class _LoadingScrim extends StatefulWidget {
  const _LoadingScrim({required this.message});

  final String message;

  @override
  State<_LoadingScrim> createState() => _LoadingScrimState();
}

class _LoadingScrimState extends State<_LoadingScrim>
    with TickerProviderStateMixin {
  late final AnimationController _haloRotate = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  // Lub-dub heartbeat curve, matching the splash screen's emblem pulse
  // rather than a plain sine ease — this is meant to read as a heartbeat,
  // not a mechanical progress meter.
  late final AnimationController _heartbeat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final Animation<double> _beat = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.14)
          .chain(CurveTween(curve: Curves.easeOutQuad)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.14, end: 1.03)
          .chain(CurveTween(curve: Curves.easeInOutQuad)),
      weight: 12,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.03, end: 1.18)
          .chain(CurveTween(curve: Curves.easeOutQuad)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
  ]).animate(_heartbeat);

  @override
  void dispose() {
    _haloRotate.dispose();
    _heartbeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Semantics(
      liveRegion: true,
      label: widget.message,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: (isDark ? Colors.black : AppColors.primaryText)
              .withValues(alpha: isDark ? 0.58 : 0.34),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating ambient dashed ring — same signature as the
                    // splash screen's emblem, at overlay scale.
                    RotationTransition(
                      turns: _haloRotate,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x55D1BE93),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),

                    // Breathing golden glow.
                    AnimatedBuilder(
                      animation: _beat,
                      builder: (context, child) {
                        return Container(
                          width: 100 * _beat.value,
                          height: 100 * _beat.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x22D1BE93),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x35E0CEB0),
                                blurRadius: 26 * _beat.value,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Emblem badge with the heartbeat pulse.
                    ScaleTransition(
                      scale: _beat,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFFDFC),
                              Color(0xFFFAF5EB),
                              Color(0xFFF1E6D3),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFD6BE88),
                            width: 2.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40B9A06A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/heart_leaf_emblem.png',
                          width: 44,
                          height: 44,
                          fallback: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.primaryGreen,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kSans,
                    fontSize: 14.5,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    // Always light: the scrim behind it is a dark tint in
                    // both themes, so this doesn't need to react to isDark.
                    color: Color(0xFFFDFBF6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
