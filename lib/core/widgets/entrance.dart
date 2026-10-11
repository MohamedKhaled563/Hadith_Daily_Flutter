import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_motion.dart';

/// Fades and rises its child into place once, when it first mounts.
///
/// The reading screens were completely still: the hadith, its explanation and
/// the daily message all simply appeared. A short, staggered rise gives the
/// screen a sense of arriving without asking anything of the reader.
///
/// Plays once per mount — rebuilds never replay it. Under reduce-motion the
/// child is shown at rest immediately.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  /// Staggers a group: give each sibling the [index] of [Entrance.staggered].
  Entrance.staggered({
    super.key,
    required this.child,
    required int index,
    this.offset = 14,
  }) : delay = Duration(milliseconds: 70 * (index > 6 ? 6 : index));

  final Widget child;
  final Duration delay;

  /// How far below its resting place the child starts, in logical pixels.
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
