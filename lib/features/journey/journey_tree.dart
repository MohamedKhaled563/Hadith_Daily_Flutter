import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/tree_memory.dart';

/// What one leaf on the tree shows: a hadith not read yet, read, or held by
/// heart.
enum LeafLook { empty, complete, memorized }

/// One leaf's fixed place on the drawing: where its stem meets the twig,
/// and the way it points, with the wind still.
class TreeLeaf {
  const TreeLeaf({
    required this.number,
    required this.at,
    required this.radians,
  });

  final int number;
  final Offset at;
  final double radians;

  /// Middle of the leaf, which is where a tap lands and its number sits.
  Offset get centre =>
      at +
      Offset(math.cos(radians), math.sin(radians)) *
          (TreeLayout.leafLength * _midLeaf);
}

/// How far from the stem the middle of a leaf image is, in leaf lengths.
const _midLeaf = .48;

/// Where the stem ends, down the leaf image, as a fraction of its height.
const _stemEnd = .984;

/// The tree's geometry, in the frame of its painting: 420 wide, and as tall
/// as the painting is for that width. The 42 leaves sit on the twig tips
/// marked by hand on the painting, numbered in a sweep from the lower left,
/// over the top, to the lower right.
class TreeLayout {
  TreeLayout._()
      : leaves = [
          for (var i = 0; i < _places.length; i++)
            TreeLeaf(
              number: i + 1,
              at: Offset(_places[i].$1, _places[i].$2),
              radians: _places[i].$3 * math.pi / 180,
            ),
        ];

  static final instance = TreeLayout._();

  static const width = 420.0;
  static const height = 352.0;
  static const leafLength = 32.6;

  /// The leaf images are 241 wide for 387 tall.
  static const leafWidth = leafLength * 241 / 387;

  /// Where the trunk meets the grass. Above it the tree leans in the wind;
  /// the ground below stays put.
  static const ground = 301.2;

  /// Each leaf's stem end, x and y, and its direction in degrees (0 points
  /// right, 90 down), traced from the painting.
  static const _places = [
    (78.7, 248.6, 141),
    (116.3, 252.3, 125),
    (48.0, 227.9, 178),
    (149.8, 243.5, 128),
    (44.8, 195.3, -145),
    (35.7, 159.5, -159),
    (84.0, 192.4, -120),
    (118.2, 204.7, -149),
    (81.5, 121.6, 167),
    (124.7, 151.1, 161),
    (100.6, 101.2, -130),
    (147.6, 174.6, -112),
    (121.9, 58.9, -123),
    (180.5, 191.8, -120),
    (160.8, 122.2, -121),
    (153.9, 81.8, -115),
    (179.9, 62.1, -125),
    (183.0, 38.6, -102),
    (201.2, 123.5, -98),
    (202.8, 80.6, -95),
    (236.3, 35.7, -105),
    (246.0, 132.3, -85),
    (273.9, 42.3, -82),
    (268.3, 90.3, -75),
    (243.9, 185.9, -71),
    (307.5, 62.7, -70),
    (296.8, 114.1, -63),
    (271.7, 175.8, -67),
    (333.8, 81.8, -62),
    (326.9, 107.2, -37),
    (357.0, 102.5, -46),
    (303.1, 181.5, -46),
    (321.3, 139.5, 14),
    (348.2, 122.2, 3),
    (382.7, 124.4, -47),
    (379.6, 159.5, -42),
    (340.7, 198.7, -43),
    (273.0, 232.6, 55),
    (384.9, 195.6, -29),
    (363.0, 211.6, -11),
    (380.2, 233.8, 10),
    (335.7, 248.2, 47),
  ];

  final List<TreeLeaf> leaves;
}

/// The painted tree and its three leaves, decoded once and kept, since the
/// tree is drawn on every frame while it sways.
class TreeArt {
  const TreeArt._(this.tree, this.leaves);

  final ui.Image tree;
  final Map<LeafLook, ui.Image> leaves;

  static const treeAsset = 'assets/images/journey/tree.webp';
  static const leafAssets = {
    LeafLook.empty: 'assets/images/journey/leaf_unread.webp',
    LeafLook.complete: 'assets/images/journey/leaf_read.webp',
    LeafLook.memorized: 'assets/images/journey/leaf_memorized.webp',
  };

  static TreeArt? _ready;
  static Future<TreeArt?>? _loading;

  /// The art, once [load] has finished.
  static TreeArt? get ready => _ready;

  static Future<TreeArt?> load() => _loading ??= _load();

  static Future<TreeArt?> _load() async {
    try {
      final tree = await _decode(treeAsset);
      final leaves = {
        for (final entry in leafAssets.entries)
          entry.key: await _decode(entry.value),
      };
      return _ready = TreeArt._(tree, leaves);
    } catch (error) {
      debugPrint('TreeArt: could not load the tree: $error');
      // Try again the next time the tree is shown.
      _loading = null;
      return null;
    }
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}

/// The colours drawn over the painting: the numbers on the leaves, and the
/// ring that spreads from a leaf as it turns. The leaves are the same
/// painting in light and dark mode, so these do not follow the theme.
@immutable
class TreeColors {
  const TreeColors._();

  static const standard = TreeColors._();

  Color get ring => AppColors.gold;

  /// The number on a leaf, readable on that leaf's colour.
  Color inkOn(LeafLook look) => switch (look) {
        LeafLook.complete => AppColors.softCream,
        LeafLook.empty => AppColors.goldText,
        LeafLook.memorized => _inkOnGold,
      };

  static final _inkOnGold =
      Color.lerp(AppColors.goldText, AppColors.darkEmerald, .4)!;
}

/// The look of every leaf for a reader.
Map<int, LeafLook> leafLooks(JourneyData data) => {
      for (final leaf in TreeLayout.instance.leaves)
        leaf.number: data.memoOf(leaf.number).isMemorized
            ? LeafLook.memorized
            : data.progressOf(leaf.number).isComplete
                ? LeafLook.complete
                : LeafLook.empty,
    };

/// The hadiths a reader has memorized, whose leaves are gold.
Set<int> memorizedLeaves(JourneyData data) => {
      for (final entry in data.memo.entries)
        if (entry.value.isMemorized) entry.key,
    };

/// The hadiths a reader has finished, whose leaves are green or gold.
Set<int> completeLeaves(JourneyData data) => {
      for (final leaf in TreeLayout.instance.leaves)
        if (data.progressOf(leaf.number).isComplete) leaf.number,
    };

/// The leaf image for [look], as it sits on the tree.
String leafAsset(LeafLook look) => TreeArt.leafAssets[look]!;

/// One leaf as it is on the tree, for the key under it.
class LeafSwatch extends StatelessWidget {
  const LeafSwatch(this.look, {super.key, this.height = 18});

  final LeafLook look;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        leafAsset(look),
        height: height,
        width: height * 241 / 387,
        excludeFromSemantics: true,
      );
}

/// The tree's clock, and what is changing on it. It ticks while the tree is
/// on screen, and the painter reads it on every frame.
class TreeMotion extends ChangeNotifier {
  static const unfoldSeconds = .9;
  static const fruitSeconds = .8;
  static const _ringSeconds = .7;
  static const _rustleSeconds = 1.4;

  /// Seconds on the tree's clock.
  double time = 0;

  final _unfold = <int, double>{};
  final _fruit = <int, double>{};
  final _rustle = <int, double>{};

  /// Leaves waiting for their turn to turn green, and to turn gold: drawn
  /// as they were until then, so nothing changes before it is seen to.
  Set<int> heldLeaves = const {};
  Set<int> heldFruit = const {};

  /// How far [number]'s leaf has turned green, 0 to 1.
  double grownOf(int number) => _progress(
        _unfold[number],
        unfoldSeconds,
        held: heldLeaves.contains(number),
      );

  /// How far [number]'s leaf has turned gold, 0 to 1.
  double fruitOf(int number) => _progress(
        _fruit[number],
        fruitSeconds,
        held: heldFruit.contains(number),
      );

  double _progress(double? start, double seconds, {required bool held}) {
    if (start == null) return held ? 0 : 1;
    return ((time - start) / seconds).clamp(0.0, 1.0);
  }

  /// The gold ring that spreads from a leaf as it turns: how far it has
  /// gone, 0 to 1, or null when there is none.
  double? ringOf(int number) {
    final start = _unfold[number] ?? _fruit[number];
    if (start == null) return null;
    final since = (time - start) / _ringSeconds;
    return since > 0 && since < 1 ? since : null;
  }

  /// How far a tapped leaf is swinging, in radians.
  double rustleOf(int number) {
    final start = _rustle[number];
    if (start == null) return 0;
    final since = time - start;
    if (since < 0 || since > _rustleSeconds) return 0;
    return math.sin(since * 18) * .5 * math.exp(-since * 4);
  }

  void unfold(int number, double at) => _unfold[number] = at;

  void grow(int number, double at) => _fruit[number] = at;

  void rustle(int number) {
    _rustle[number] = time;
    notifyListeners();
  }

  /// Whether anything is turning or swinging at [now], or waiting to: that
  /// wants every frame, where the wind alone does with fewer.
  bool busyAt(double now) {
    bool pending(Map<int, double> starts, double seconds) =>
        starts.values.any((start) => now - start < seconds);
    return pending(_unfold, unfoldSeconds) ||
        pending(_fruit, fruitSeconds) ||
        pending(_rustle, _rustleSeconds);
  }

  void advance(double now) {
    time = now;
    _unfold.removeWhere((_, start) => now - start > unfoldSeconds);
    _fruit.removeWhere((_, start) => now - start > fruitSeconds);
    _rustle.removeWhere((_, start) => now - start > _rustleSeconds);
    notifyListeners();
  }

  void reset() {
    time = 0;
    _unfold.clear();
    _fruit.clear();
    _rustle.clear();
    heldLeaves = const {};
    heldFruit = const {};
  }
}

/// A leaf part way from one look to the next: [t] runs from 0, all [from],
/// to 1, all [to].
typedef _Turning = ({LeafLook from, LeafLook to, double t});

_Turning _turning(LeafLook look, int number, TreeMotion? motion) {
  final grown = motion?.grownOf(number) ?? 1;
  return switch (look) {
    LeafLook.empty => (from: look, to: look, t: 1),
    LeafLook.complete => (from: LeafLook.empty, to: look, t: grown),
    // Green first, if the reader has not seen it read; then gold.
    LeafLook.memorized when grown < 1 => (
        from: LeafLook.empty,
        to: LeafLook.complete,
        t: grown,
      ),
    LeafLook.memorized => (
        from: LeafLook.complete,
        to: look,
        t: motion?.fruitOf(number) ?? 1,
      ),
  };
}

/// The numbers on the leaves, laid out once.
final _labels = <(int, LeafLook), TextPainter>{};

TextPainter _label(int number, LeafLook look) =>
    _labels[(number, look)] ??= TextPainter(
      text: TextSpan(
        text: toArabicDigits(number),
        style: TextStyle(
          fontFamily: kSans,
          fontSize: TreeLayout.leafLength * .3,
          height: 1,
          fontWeight: FontWeight.w800,
          color: TreeColors.standard.inkOn(look),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

class JourneyTreePainter extends CustomPainter {
  const JourneyTreePainter({
    required this.looks,
    this.art,
    this.motion,
    this.titleOf,
    this.onLeafTap,
  }) : super(repaint: motion);

  final Map<int, LeafLook> looks;

  /// The painting. Until it has loaded only the semantics are there.
  final TreeArt? art;

  /// The wind and whatever is turning. Null draws the tree still, as on a
  /// poster or with reduced motion.
  final TreeMotion? motion;

  /// Announces each leaf to a screen reader. Null on a poster.
  final String Function(int number)? titleOf;
  final ValueChanged<int>? onLeafTap;

  /// The leaves that are gold: the hadiths held by heart.
  Set<int> get memorized => {
        for (final entry in looks.entries)
          if (entry.value == LeafLook.memorized) entry.key,
      };

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
    var nearestDistance = 22.0;
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
    final art = this.art;
    if (art == null) return;
    final motion = this.motion;
    final time = motion?.time;
    // How far the tree leans: the top moves a few units at most, so a tap
    // still finds a leaf by its still place.
    final lean = switch (time) {
      final t? => (math.sin(t * .9) + .4 * math.sin(t * 2.1 + 1)) * .008,
      null => 0.0,
    };
    Offset leaning(Offset point) =>
        Offset(point.dx + lean * (TreeLayout.ground - point.dy), point.dy);

    final scale = _scaleFor(size);
    canvas
      ..save()
      ..translate(_originFor(size).dx, _originFor(size).dy)
      ..scale(scale);

    _paintTree(canvas, art.tree, lean);

    final leafPaint = Paint()..filterQuality = FilterQuality.medium;
    for (final leaf in TreeLayout.instance.leaves) {
      final number = leaf.number;
      final (:from, :to, :t) =
          _turning(looks[number] ?? LeafLook.empty, number, motion);
      final flutter = switch (time) {
        final t? => math.sin(t * 3.2 + number * 1.9) * .06,
        null => 0.0,
      };
      final radians = leaf.radians + flutter + (motion?.rustleOf(number) ?? 0);
      final at = leaning(leaf.at);
      // A leaf swells a little as it turns, so the eye catches it.
      final swell = 1 + .22 * math.sin(math.pi * t);

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(radians + math.pi / 2)
        ..scale(swell);
      if (t < 1) _paintLeaf(canvas, art.leaves[from]!, leafPaint, 1);
      if (t > 0) _paintLeaf(canvas, art.leaves[to]!, leafPaint, t);
      canvas.restore();

      final centre = at +
          Offset(math.cos(radians), math.sin(radians)) *
              (TreeLayout.leafLength * _midLeaf * swell);
      if (motion?.ringOf(number) case final ring?) {
        canvas.drawCircle(
          centre,
          6 + ring * 18,
          Paint()
            ..color = TreeColors.standard.ring.withValues(alpha: 1 - ring)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      // Upright whichever way the leaf points, to be read at a glance.
      final label = _label(number, t > .5 ? to : from);
      label.paint(
        canvas,
        centre - Offset(label.width / 2, label.height / 2 - .6),
      );
    }
    canvas.restore();
  }

  void _paintTree(Canvas canvas, ui.Image tree, double lean) {
    final source = Rect.fromLTWH(
      0,
      0,
      tree.width.toDouble(),
      tree.height.toDouble(),
    );
    const frame = Rect.fromLTWH(0, 0, TreeLayout.width, TreeLayout.height);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (lean == 0) {
      canvas.drawImageRect(tree, source, frame, paint);
      return;
    }
    // The ground as it is; above it the tree leans from where the trunk
    // meets the grass, the top moving most. The two meet without a seam,
    // since the lean is nothing at the ground line.
    canvas
      ..save()
      ..clipRect(
        const Rect.fromLTRB(
          -40,
          TreeLayout.ground,
          TreeLayout.width + 40,
          TreeLayout.height,
        ),
        doAntiAlias: false,
      )
      ..drawImageRect(tree, source, frame, paint)
      ..restore()
      ..save()
      ..clipRect(
        const Rect.fromLTRB(
          -40,
          -40,
          TreeLayout.width + 40,
          TreeLayout.ground,
        ),
        doAntiAlias: false,
      )
      ..translate(lean * TreeLayout.ground, 0)
      ..skew(-lean, 0)
      ..drawImageRect(tree, source, frame, paint)
      ..restore();
  }

  /// A leaf image pointing up from its stem at the origin.
  static void _paintLeaf(
    Canvas canvas,
    ui.Image leaf,
    Paint paint,
    double opacity,
  ) {
    canvas.drawImageRect(
      leaf,
      Rect.fromLTWH(0, 0, leaf.width.toDouble(), leaf.height.toDouble()),
      const Rect.fromLTWH(
        -TreeLayout.leafWidth / 2,
        -TreeLayout.leafLength * _stemEnd,
        TreeLayout.leafWidth,
        TreeLayout.leafLength,
      ),
      paint..color = Color.fromRGBO(0, 0, 0, opacity),
    );
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
              width: 30 * scale,
              height: 30 * scale,
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
      oldDelegate.art != art ||
      oldDelegate.motion != motion ||
      !_sameLooks(oldDelegate.looks);

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

/// The reader's tree on screen, alive: it leans in the wind, a tapped leaf
/// rustles, and what the reader finished since they last looked turns green
/// in front of them, and gold once memorized. Once a day every leaf turns
/// again, as a greeting. Still when the phone asks for reduced motion.
/// Tapping a leaf opens that hadith.
class JourneyTree extends StatefulWidget {
  const JourneyTree({
    super.key,
    required this.data,
    required this.titleOf,
    required this.onLeafTap,
    this.account,
    this.today,
    this.ready = true,
  });

  final JourneyData data;
  final String Function(int number) titleOf;
  final ValueChanged<int> onLeafTap;

  /// Whose tree this is, for remembering what it has shown them. Null is a
  /// guest.
  final String? account;

  /// The journey day, for the once-a-day greeting. Null skips it.
  final String? today;

  /// Whether [data] is the reader's own yet. Until it is, nothing is grown
  /// or remembered: an account's leaves arriving from the server are not
  /// new leaves.
  final bool ready;

  @override
  State<JourneyTree> createState() => _JourneyTreeState();
}

class _JourneyTreeState extends State<JourneyTree>
    with SingleTickerProviderStateMixin {
  final _motion = TreeMotion();
  late final Ticker _ticker = createTicker(_tick);

  TreeArt? _art = TreeArt.ready;
  TreeSeen? _seen;
  bool _still = false;

  /// Something is held back and waits for the tree to be on screen.
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (_art == null) unawaited(_loadArt());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = context.reduceMotion;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _motion.reset();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
    _hold();
  }

  @override
  void didUpdateWidget(JourneyTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _seen = null;
      unawaited(_load());
    }
    _hold();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _loadArt() async {
    final art = await TreeArt.load();
    if (mounted && art != null) setState(() => _art = art);
  }

  Future<void> _load() async {
    final account = widget.account;
    final seen = await TreeMemory.load(account);
    if (!mounted || widget.account != account) return;
    setState(() {
      _seen = seen;
      _hold();
    });
  }

  /// Holds back every leaf the reader has not seen turn, so it keeps its
  /// old look until the tree is on screen to turn it.
  void _hold() {
    final seen = _seen;
    if (seen == null || !widget.ready) {
      _motion
        ..heldLeaves = const {}
        ..heldFruit = const {};
      _waiting = false;
      return;
    }
    final complete = completeLeaves(widget.data);
    final fruit = memorizedLeaves(widget.data);
    if (_still) {
      _waiting = false;
      _remember(complete, fruit);
      return;
    }
    final greeting = widget.today != null && seen.day != widget.today;
    _motion
      ..heldLeaves = greeting ? complete : complete.difference(seen.leaves)
      ..heldFruit = greeting ? fruit : fruit.difference(seen.fruit);
    _waiting = greeting ||
        _motion.heldLeaves.isNotEmpty ||
        _motion.heldFruit.isNotEmpty;
  }

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // A muted ticker does not tick, so this runs once the tree is showing.
    // The painting is loaded long before: the tab is built at start-up.
    if (_waiting) _grow(now);
    // The wind needs no more than thirty frames a second; turning does.
    if (!_motion.busyAt(now) && now - _motion.time < 1 / 30) return;
    _motion.advance(now);
  }

  /// Turns the held leaves green one after another, then the memorized
  /// ones gold.
  void _grow(double now) {
    _waiting = false;
    final leaves = _motion.heldLeaves.toList()..sort();
    final fruit = _motion.heldFruit.toList()..sort();
    var at = now + .3;
    final gap = leaves.length > 6 ? .035 : .12;
    for (final number in leaves) {
      _motion.unfold(number, at);
      at += gap;
    }
    if (leaves.isNotEmpty) at += TreeMotion.unfoldSeconds * .6;
    for (final number in fruit) {
      _motion.grow(number, at);
      at += .15;
    }
    _motion
      ..heldLeaves = const {}
      ..heldFruit = const {};
    _remember(completeLeaves(widget.data), memorizedLeaves(widget.data));
  }

  void _remember(Set<int> complete, Set<int> fruit) {
    final seen = _seen;
    if (seen == null) return;
    final next = TreeSeen(
      leaves: {...seen.leaves, ...complete},
      fruit: fruit,
      day: widget.today ?? seen.day,
    );
    if (setEquals(next.leaves, seen.leaves) &&
        setEquals(next.fruit, seen.fruit) &&
        next.day == seen.day) {
      return;
    }
    _seen = next;
    unawaited(TreeMemory.save(widget.account, next));
  }

  String _describe(int number, LeafLook look) {
    final state = switch (look) {
      LeafLook.complete => 'مكتمل',
      LeafLook.memorized => 'مكتمل، وفي حفظك',
      LeafLook.empty => 'لم يُقرأ بعد',
    };
    return 'الحديث ${toArabicDigits(number)}: ${widget.titleOf(number)}، '
        '$state';
  }

  @override
  Widget build(BuildContext context) {
    final looks = leafLooks(widget.data);

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
              if (number == null) return;
              if (!_still) _motion.rustle(number);
              widget.onLeafTap(number);
            },
            // The wind repaints the tree alone, not the card around it.
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: JourneyTreePainter(
                  looks: looks,
                  art: _art,
                  motion: _still ? null : _motion,
                  titleOf: (number) => _describe(number, looks[number]!),
                  onLeafTap: widget.onLeafTap,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single green leaf for the completion sheet, swelling into place when
/// motion is on.
class CompletedLeaf extends StatelessWidget {
  const CompletedLeaf({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 620),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.rotate(
        angle: -.35 * value,
        child: Transform.scale(scale: .4 + .6 * value, child: child),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          leafAsset(LeafLook.complete),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
