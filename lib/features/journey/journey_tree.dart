import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../data/journey/journey_models.dart';

/// What one leaf on the tree shows.
enum LeafLook { empty, next, started, complete }

/// One leaf's fixed place on the 420×470 drawing.
class TreeLeaf {
  const TreeLeaf({
    required this.number,
    required this.at,
    required this.radians,
  });

  final int number;
  final Offset at;
  final double radians;

  /// Middle of the leaf, which is where a tap lands.
  Offset get centre =>
      at +
      Offset(math.cos(radians), math.sin(radians)) * TreeLayout.leafLength / 2;
}

class TreeBranch {
  const TreeBranch(this.from, this.control, this.to);

  final Offset from;
  final Offset control;
  final Offset to;
}

/// The tree's geometry: one trunk and twelve branches carrying 42 leaves,
/// hadith 1 at the bottom and 42 at the top. Worked out once, because it
/// never changes, and shared by the screen and anything that draws the tree
/// off-stage.
class TreeLayout {
  TreeLayout._() {
    const counts = [4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3];
    var number = 0;
    for (var i = 0; i < counts.length; i++) {
      final along = (i + .7) / 12.6;
      final from = _onTrunk(along);
      final side = i.isOdd ? 1.0 : -1.0;
      final length = 168 - (along - .3).abs() * 130;
      final to = Offset(from.dx + side * length, math.max(26, from.dy - 48));
      final control = Offset(from.dx + side * length * .45, from.dy - 6);
      branches.add(TreeBranch(from, control, to));

      for (var j = 0; j < counts[i]; j++) {
        final t = (j + 1) / counts[i] * .86 + .14;
        final u = 1 - t;
        final at = from * (u * u) + control * (2 * u * t) + to * (t * t);
        final tangent = (control - from) * (2 * u) + (to - control) * (2 * t);
        var radians = math.atan2(tangent.dy, tangent.dx);
        if (j < counts[i] - 1) radians += (j.isOdd ? 42 : -42) * math.pi / 180;
        leaves.add(TreeLeaf(number: ++number, at: at, radians: radians));
      }
    }
  }

  static final instance = TreeLayout._();

  static const width = 420.0;
  static const height = 470.0;
  static const leafLength = 26.0;

  static const _trunk = [
    Offset(210, 466),
    Offset(200, 340),
    Offset(222, 220),
    Offset(212, 40),
  ];

  final branches = <TreeBranch>[];
  final leaves = <TreeLeaf>[];

  static Offset _onTrunk(double s) {
    final u = 1 - s;
    return _trunk[0] * (u * u * u) +
        _trunk[1] * (3 * u * u * s) +
        _trunk[2] * (3 * u * s * s) +
        _trunk[3] * (s * s * s);
  }

  static Path trunkPath() => Path()
    ..moveTo(_trunk[0].dx, _trunk[0].dy)
    ..cubicTo(
      _trunk[1].dx,
      _trunk[1].dy,
      _trunk[2].dx,
      _trunk[2].dy,
      _trunk[3].dx,
      _trunk[3].dy,
    );

  /// A leaf lying along the x axis, starting at the origin.
  static Path leafPath() => Path()
    ..moveTo(0, 0)
    ..cubicTo(7, -9, 19, -9, leafLength, 0)
    ..cubicTo(19, 9, 7, 9, 0, 0)
    ..close();
}

/// The colours the tree is drawn in. Separate from the theme so a poster,
/// which is always the light treatment, can draw the same tree.
@immutable
class TreeColors {
  const TreeColors({
    required this.wood,
    required this.emptyFill,
    required this.emptyEdge,
    required this.started,
    required this.complete,
    required this.memorized,
  });

  factory TreeColors.of(BuildContext context) {
    final palette = context.palette;
    return TreeColors(
      wood: palette.goldText.withValues(alpha: .6),
      emptyFill: palette.surfaceSunken,
      emptyEdge: palette.cardBorderStrong,
      started: context.isDarkMode
          ? AppColors.primaryGreenDark
          : AppColors.primaryGreen,
      complete: palette.ornamentGold,
      memorized: palette.warm,
    );
  }

  /// Always the light treatment, for a poster, whichever mode the reader is
  /// in. Same reason as ShareCard.
  factory TreeColors.poster() => TreeColors(
        wood: BotanicalPalette.light.goldText.withValues(alpha: .6),
        emptyFill: const Color(0xFFE6DDCA),
        emptyEdge: const Color(0xFFC9B58A),
        started: AppColors.primaryGreen,
        complete: BotanicalPalette.light.ornamentGold,
        memorized: BotanicalPalette.light.warm,
      );

  final Color wood;
  final Color emptyFill;
  final Color emptyEdge;
  final Color started;
  final Color complete;

  /// The dot on a memorized leaf.
  final Color memorized;

  @override
  bool operator ==(Object other) =>
      other is TreeColors &&
      other.wood == wood &&
      other.emptyFill == emptyFill &&
      other.emptyEdge == emptyEdge &&
      other.started == started &&
      other.complete == complete &&
      other.memorized == memorized;

  @override
  int get hashCode =>
      Object.hash(wood, emptyFill, emptyEdge, started, complete, memorized);
}

/// The hadiths a reader has memorized, which get a dot on their leaf.
Set<int> memorizedLeaves(JourneyData data) => {
      for (final entry in data.memo.entries)
        if (entry.value.isMemorized) entry.key,
    };

/// The look of every leaf for a reader, with [next] picked out as the leaf
/// waiting today.
Map<int, LeafLook> leafLooks(JourneyData data, {int? next}) => {
      for (final leaf in TreeLayout.instance.leaves)
        leaf.number: switch (data.progressOf(leaf.number)) {
          HadithProgress(isComplete: true) => LeafLook.complete,
          _ when leaf.number == next => LeafLook.next,
          HadithProgress(textOn: != null) => LeafLook.started,
          _ => LeafLook.empty,
        },
    };

/// One leaf as [look] shows it, lying along the x axis from the origin. The
/// tree and its key both draw with this, so the key always matches.
void paintLeaf(
  Canvas canvas,
  LeafLook look,
  TreeColors colors, {
  bool memorized = false,
}) {
  final path = TreeLayout.leafPath();
  final fill = switch (look) {
    LeafLook.empty => colors.emptyFill,
    LeafLook.next => colors.emptyFill,
    LeafLook.started => colors.started,
    LeafLook.complete => colors.complete,
  };
  final edge = switch (look) {
    LeafLook.empty => colors.emptyEdge,
    LeafLook.next => colors.started,
    LeafLook.started => colors.started,
    LeafLook.complete => colors.complete,
  };

  canvas
    ..drawPath(path, Paint()..color = fill)
    ..drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = switch (look) {
          LeafLook.next => 2.4,
          LeafLook.empty => 1.3,
          _ => 1,
        },
    );
  if (memorized) {
    canvas.drawCircle(
      const Offset(TreeLayout.leafLength / 2, 0),
      3.4,
      Paint()..color = colors.memorized,
    );
  }
}

/// One leaf drawn as it is on the tree, for the key under it.
class LeafSwatch extends StatelessWidget {
  const LeafSwatch(this.look, {super.key, this.memorized = false});

  final LeafLook look;
  final bool memorized;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(24, 14),
        painter: _SwatchPainter(
          look,
          TreeColors.of(context),
          memorized: memorized,
        ),
      );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.look, this.colors, {required this.memorized});

  final LeafLook look;
  final TreeColors colors;
  final bool memorized;

  @override
  void paint(Canvas canvas, Size size) {
    // A little room for the outline, which is drawn on the leaf's edge.
    final scale = size.width / (TreeLayout.leafLength + 3);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-TreeLayout.leafLength / 2, 0);
    paintLeaf(canvas, look, colors, memorized: memorized);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.colors != colors ||
      oldDelegate.memorized != memorized;
}

class JourneyTreePainter extends CustomPainter {
  const JourneyTreePainter({
    required this.looks,
    required this.colors,
    this.memorized = const {},
    this.titleOf,
    this.onLeafTap,
  });

  final Map<int, LeafLook> looks;
  final TreeColors colors;

  /// Leaves with a dot: the hadiths held by heart.
  final Set<int> memorized;

  /// Announces each leaf to a screen reader. Null on a poster.
  final String Function(int number)? titleOf;
  final ValueChanged<int>? onLeafTap;

  static double _scaleFor(Size size) => math.min(
        size.width / TreeLayout.width,
        size.height / TreeLayout.height,
      );

  static Offset _originFor(Size size) {
    final scale = _scaleFor(size);
    return Offset(
      (size.width - TreeLayout.width * scale) / 2,
      (size.height - TreeLayout.height * scale) / 2,
    );
  }

  /// The hadith under [point], or null if the tap landed on bare branches.
  static int? hitLeaf(Offset point, Size size) {
    final scale = _scaleFor(size);
    final local = (point - _originFor(size)) / scale;
    TreeLeaf? nearest;
    var nearestDistance = 26.0;
    for (final leaf in TreeLayout.instance.leaves) {
      final distance = (leaf.centre - local).distance;
      if (distance < nearestDistance) {
        nearest = leaf;
        nearestDistance = distance;
      }
    }
    return nearest?.number;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scaleFor(size);
    canvas
      ..save()
      ..translate(_originFor(size).dx, _originFor(size).dy)
      ..scale(scale);

    final wood = Paint()
      ..color = colors.wood
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(TreeLayout.trunkPath(), wood..strokeWidth = 7);
    wood.strokeWidth = 3;
    for (final branch in TreeLayout.instance.branches) {
      canvas.drawPath(
        Path()
          ..moveTo(branch.from.dx, branch.from.dy)
          ..quadraticBezierTo(
            branch.control.dx,
            branch.control.dy,
            branch.to.dx,
            branch.to.dy,
          ),
        wood,
      );
    }

    for (final leaf in TreeLayout.instance.leaves) {
      canvas
        ..save()
        ..translate(leaf.at.dx, leaf.at.dy)
        ..rotate(leaf.radians);
      paintLeaf(
        canvas,
        looks[leaf.number] ?? LeafLook.empty,
        colors,
        memorized: memorized.contains(leaf.number),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder {
    final title = titleOf;
    if (title == null) return null;

    return (size) {
      final scale = _scaleFor(size);
      final origin = _originFor(size);
      return [
        for (final leaf in TreeLayout.instance.leaves)
          CustomPainterSemantics(
            rect: Rect.fromCenter(
              center: origin + leaf.centre * scale,
              width: 40 * scale,
              height: 40 * scale,
            ),
            properties: SemanticsProperties(
              label: title(leaf.number),
              textDirection: TextDirection.rtl,
              button: true,
              onTap: onLeafTap == null ? null : () => onLeafTap!(leaf.number),
            ),
          ),
      ];
    };
  }

  @override
  bool shouldRepaint(JourneyTreePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !_sameLooks(oldDelegate.looks) ||
      !setEquals(oldDelegate.memorized, memorized);

  @override
  bool shouldRebuildSemantics(JourneyTreePainter oldDelegate) =>
      !_sameLooks(oldDelegate.looks);

  bool _sameLooks(Map<int, LeafLook> other) {
    if (other.length != looks.length) return false;
    for (final entry in looks.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// The reader's tree on screen. Tapping a leaf opens that hadith.
class JourneyTree extends StatelessWidget {
  const JourneyTree({
    super.key,
    required this.data,
    required this.titleOf,
    required this.onLeafTap,
    this.next,
  });

  final JourneyData data;

  /// The hadith waiting today, outlined so the eye finds where to go next.
  final int? next;
  final String Function(int number) titleOf;
  final ValueChanged<int> onLeafTap;

  String _describe(int number, LeafLook look, {required bool memorized}) {
    final state = switch (look) {
      LeafLook.complete => 'مكتمل',
      LeafLook.next => 'حديث اليوم',
      LeafLook.started => 'بدأت قراءته',
      LeafLook.empty => 'لم يُقرأ بعد',
    };
    final held = memorized ? '، في حفظك' : '';
    return 'الحديث ${toArabicDigits(number)}: ${titleOf(number)}، $state$held';
  }

  @override
  Widget build(BuildContext context) {
    final looks = leafLooks(data, next: next);
    final memorized = memorizedLeaves(data);

    return AspectRatio(
      aspectRatio: TreeLayout.width / TreeLayout.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final number =
                  JourneyTreePainter.hitLeaf(details.localPosition, size);
              if (number != null) onLeafTap(number);
            },
            child: CustomPaint(
              size: size,
              painter: JourneyTreePainter(
                looks: looks,
                colors: TreeColors.of(context),
                memorized: memorized,
                titleOf: (number) => _describe(
                  number,
                  looks[number]!,
                  memorized: memorized.contains(number),
                ),
                onLeafTap: onLeafTap,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single gold leaf for the completion sheet, growing in when motion is on.
class CompletedLeaf extends StatelessWidget {
  const CompletedLeaf({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: lerpDouble(.5, 1, value),
        child: child,
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: _SingleLeafPainter(
          context.palette.ornamentGold,
          vein: context.palette.parchmentTop,
        ),
      ),
    );
  }
}

class _SingleLeafPainter extends CustomPainter {
  const _SingleLeafPainter(this.color, {required this.vein});

  final Color color;
  final Color vein;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / (TreeLayout.leafLength + 4);
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-.6)
      ..scale(scale)
      ..translate(-TreeLayout.leafLength / 2, 0)
      ..drawPath(TreeLayout.leafPath(), Paint()..color = color)
      ..drawLine(
        const Offset(3, 0),
        const Offset(TreeLayout.leafLength - 4, 0),
        Paint()
          ..color = vein
          ..strokeWidth = .7
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_SingleLeafPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.vein != vein;
}
