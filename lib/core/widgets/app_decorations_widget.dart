import 'package:flutter/material.dart';
import 'app_decorations.dart';

class AppDecorationsWidget {
  static Widget get heartLeafEmblem => AppDecorations.heartLeafEmblem(size: 46);
  static Widget get goldenDivider => AppDecorations.goldenDivider(width: 80, height: 12);
  static Widget get flowerBadge => AppDecorations.flowerBadge(size: 38);
  static Widget get leafBadge => AppDecorations.leafBadge(size: 38);
  static Widget get botanicalTopRight => AppDecorations.botanicalTopRight(width: 130, height: 160);
  static Widget get botanicalBottomLeft => AppDecorations.botanicalBottomLeft(width: 130, height: 160);
  static Widget get sunsetLandscape => AppDecorations.sunsetLandscape(height: 220);
}
