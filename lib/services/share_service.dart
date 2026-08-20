import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a widget off-screen, captures it as PNG and opens the native
/// share sheet.
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

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
      ),
    );
  }

  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
