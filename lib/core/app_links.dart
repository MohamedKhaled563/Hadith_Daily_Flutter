import 'dart:io';

/// Where a reader can get the app, for embedding in shared text.
///
/// The Play Store link is fully determined by the applicationId already set
/// in `android/app/build.gradle` — it works the day the app is published,
/// with zero code changes, so it's safe to ship now even pre-launch.
class AppLinks {
  const AppLinks._();

  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.prodktstudio.tayebqalbak';

  // TODO(ios-app-link): Apple's numeric App Store id only exists once this
  // app is registered in App Store Connect (My Apps -> + -> New App) — it's
  // assigned immediately, before the app is actually submitted, so it can be
  // filled in well ahead of release. Once you have it, set it here as
  // 'https://apps.apple.com/app/id<NUMERIC_ID>' and [storeLink] below will
  // start including it on iOS automatically.
  static const String? appStore = null;

  /// The right store link for the current platform, or null when there
  /// isn't one yet (iOS, until [appStore] is filled in) — callers should
  /// simply omit the line rather than show a wrong-platform link.
  static String? get storeLink {
    if (Platform.isIOS) return appStore;
    if (Platform.isAndroid) return playStore;
    return null;
  }
}
