/// Facts about this build that the UI shows the reader.
///
/// The version used to be a literal typed into the settings drawer, which is
/// fine exactly once: the first `version:` bump in `pubspec.yaml` leaves the
/// drawer confidently telling every reader the wrong number, and nothing
/// fails when it does.
///
/// Reading the real installed version would mean `package_info_plus` — a
/// native plugin on both platforms — for one line of chrome. The cheaper
/// answer is one constant plus a test that parses `pubspec.yaml` and refuses
/// to let the two drift, which turns a silent lie into a failing build and
/// costs nothing at runtime. See `test/app_info_test.dart`.
class AppInfo {
  const AppInfo._();

  /// Must match `version:` in pubspec.yaml, before the `+buildNumber`.
  static const version = '1.0.0';
}
