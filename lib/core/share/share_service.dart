import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'share_card.dart';

/// Renders a [ShareCard] to a PNG and hands it to the platform share sheet,
/// which is what surfaces WhatsApp, Messages, Photos, Facebook and everything
/// else the device has installed.
///
/// The card is rendered off-stage rather than captured from a `RepaintBoundary`
/// in the live tree. Capturing the on-screen widget would bake in whatever the
/// reader's theme and text-scale happen to be, and would be clipped to the
/// phone's aspect ratio; building it off-stage gives a fixed, predictable
/// 1080×1350 poster every time.
class ShareService {
  const ShareService._();

  /// 3× the card's logical size, giving 1080×1350.
  static const double _pixelRatio = 3.0;

  static Future<void> shareMessage({
    required BuildContext context,
    required String message,
    String? hadithTitle,
    String? hadithNumber,
    String? attribution,
    String? category,
    String? fallbackText,
  }) async {
    // Where the sheet anchors on iPad; harmless elsewhere.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final caption = fallbackText ?? _caption(message, hadithTitle, hadithNumber);

    try {
      final bytes = await _renderCard(
        context: context,
        card: ShareCard(
          message: message,
          hadithTitle: hadithTitle,
          hadithNumber: hadithNumber,
          attribution: attribution,
          category: category,
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tayyib-qalbak-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: caption,
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stackTrace) {
      // Rendering can fail on a device with an exhausted GPU context. Falling
      // back to plain text still gets the message shared, which is the point.
      assert(() {
        debugPrint('ShareService: image render failed, sharing text. $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());

      await SharePlus.instance.share(
        ShareParams(text: caption, sharePositionOrigin: origin),
      );
    }
  }

  static String _caption(String message, String? title, String? number) {
    final buffer = StringBuffer('« $message »');
    if (title != null && title.trim().isNotEmpty) {
      buffer.write('\n\n📌 ');
      buffer.write(number == null ? title : 'الحديث $number: $title');
    }
    buffer.write('\n🌿 من تطبيق «طيّب قلبك»');
    return buffer.toString();
  }

  /// Assets the poster draws. They must be in the image cache before the
  /// off-stage render, because an `Image.asset` that has to load
  /// asynchronously will not have painted by the time the canvas is captured —
  /// it would produce a poster with the emblem and botanicals missing.
  static const _cardAssets = <String>[
    'assets/images/heart_leaf_emblem.png',
    'assets/images/golden_divider.png',
    'assets/images/botanical_top_right.png',
    'assets/images/botanical_bottom_left.png',
  ];

  /// Builds [card] in its own render tree, off-stage, and rasterises it.
  ///
  /// The boundary is hung under a [RenderView] rather than being made the
  /// pipeline root directly. A bare `RenderRepaintBoundary` never gets a
  /// composited layer, so `toImage` trips its `!debugNeedsPaint` assertion —
  /// the RenderView is what drives the paint through to a layer.
  static Future<Uint8List> _renderCard({
    required BuildContext context,
    required Widget card,
  }) async {
    // The poster's artwork must already be decoded: an `Image.asset` that has
    // to load asynchronously will not have painted by the time the canvas is
    // captured, producing a poster with the emblem and botanicals missing.
    for (final asset in _cardAssets) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {
        // A missing asset falls back to vector art inside the card; not fatal.
      }
    }
    if (!context.mounted) {
      throw StateError('context unmounted before render');
    }

    final flutterView = View.of(context);

    final boundary = RenderRepaintBoundary();
    final pipeline = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    const size = Size(ShareCard.width, ShareCard.height);

    final renderView = RenderView(
      view: flutterView,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: boundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * _pixelRatio),
        devicePixelRatio: _pixelRatio,
      ),
    );

    pipeline.rootNode = renderView;
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        // Pin the text scale: the poster must not inherit the reader's
        // accessibility setting, or the layout overflows its fixed canvas.
        data: const MediaQueryData(
          size: size,
          devicePixelRatio: _pixelRatio,
          textScaler: TextScaler.noScaling,
        ),
        child: card,
      ),
    ).attachToRenderTree(buildOwner);

    try {
      buildOwner
        ..buildScope(rootElement)
        ..finalizeTree();

      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();

      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (data == null) {
        throw StateError('toByteData returned null');
      }
      return data.buffer.asUint8List();
    } finally {
      // Always tear down, or the orphaned subtree keeps its render objects
      // and elements alive.
      buildOwner.finalizeTree();
      pipeline.rootNode = null;
    }
  }
}
