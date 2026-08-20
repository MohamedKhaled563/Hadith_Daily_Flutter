import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Renders the given widget off-screen, captures it as a PNG, and opens
/// the native share sheet. Used to share a hadith card "as an image"
/// (like the reference app), not just as plain text.
class ShareService {
  static final ScreenshotController _controller = ScreenshotController();

  static Future<void> shareWidgetAsImage({
    required Widget widget,
    required String fileName,
    String? text,
  }) async {
    final Uint8List bytes = await _controller.captureFromWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: Colors.transparent,
          child: widget,
        ),
      ),
      pixelRatio: 3.0,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
    );
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
