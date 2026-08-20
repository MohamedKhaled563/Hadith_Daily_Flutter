import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  void set(String value) {
    mode.value = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
