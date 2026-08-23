import 'package:flutter/material.dart';

/// Standard press feedback for the app: a gentle scale-down.
///
/// Two magnitudes only — [cardScale] for large surfaces, [iconScale] for
/// compact controls. Previously six different constants were used across five
/// files, so nothing felt like the same app twice.
class AppPress {
  static const cardScale = 0.97;
  static const iconScale = 0.92;
  static const duration = Duration(milliseconds: 140);
  static const curve = Curves.easeOutCubic;

  /// Minimum touch target per Material and the iOS HIG.
  static const minTouchTarget = 48.0;
}

/// Wraps a control in a properly sized, properly labelled touch target.
///
/// The visual keeps its natural size; the *target* grows around it to at least
/// 48×48dp. Requiring [semanticLabel] is deliberate — icon-only controls are
/// otherwise announced as unlabelled buttons.
class TapTarget extends StatefulWidget {
  const TapTarget({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.minSize = AppPress.minTouchTarget,
    this.pressScale = AppPress.iconScale,
    this.toggled,
    this.selected,
    this.enableFeedback = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final double minSize;
  final double pressScale;

  /// Set for controls that flip between two states (bookmark, like), so the
  /// state is announced rather than being conveyed by icon shape alone.
  final bool? toggled;
  final bool? selected;
  final bool enableFeedback;

  @override
  State<TapTarget> createState() => _TapTargetState();
}

class _TapTargetState extends State<TapTarget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      toggled: widget.toggled,
      selected: widget.selected,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          // onTap rather than onTapUp: onTapUp still fires when the finger has
          // slid off the control, which produces mis-taps.
          onTap: () {
            _setPressed(false);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? widget.pressScale : 1.0,
            duration: AppPress.duration,
            curve: AppPress.curve,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.minSize,
                minHeight: widget.minSize,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Press feedback for large surfaces (cards, banners) that already carry their
/// own hit area, so no minimum-size constraint is imposed.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.pressScale = AppPress.cardScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double pressScale;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          _setPressed(false);
          widget.onTap!();
        },
        child: AnimatedScale(
          scale: _pressed ? widget.pressScale : 1.0,
          duration: AppPress.duration,
          curve: AppPress.curve,
          child: widget.child,
        ),
      ),
    );
  }
}
