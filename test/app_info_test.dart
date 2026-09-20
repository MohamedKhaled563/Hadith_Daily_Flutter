import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/app_info.dart';

/// The settings drawer shows a version number. It used to be a literal typed
/// into the widget, so the first `version:` bump would have left it telling
/// every reader the wrong number with nothing failing.
///
/// Reading the installed version properly means `package_info_plus` — a
/// native plugin on both platforms — for one line of chrome. This is the
/// cheaper half of that trade: the constant stays, and drift becomes a failing
/// test instead of a silent lie.

void main() {
  test('AppInfo.version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    // pubspec carries `1.0.0+1`; the drawer shows the human half.
    final declared = match!.group(1)!.split('+').first;

    expect(
      AppInfo.version,
      declared,
      reason: 'lib/core/app_info.dart says ${AppInfo.version} but pubspec.yaml '
          'says $declared — bump both, or the drawer lies to every reader',
    );
  });
}
