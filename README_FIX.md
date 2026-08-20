# Hadith Daily V6 — Fix

This is a corrected version of the V6 patch after running `flutter analyze`.

## What was fixed
- Added the three notification dependencies directly to `pubspec.yaml`:
  - `flutter_local_notifications: ^22.3.0`
  - `flutter_timezone: ^5.1.0`
  - `timezone: ^0.11.1`
- Fixed the `flutter_timezone 5.1.0` API usage from `zone.name` to `zone.identifier`.
- Removed the unused `alreadyRead` local variable.
- Removed the unused `app_theme.dart` import from onboarding.
- Removed the unnecessary string interpolation warning in Home.

## Apply
Replace your current V6 files with this patch, or copy the included `pubspec.yaml` and `lib/` files into the project.

Then run:

```bash
flutter clean
flutter pub get
flutter analyze
```

The `flutter_timezone` API returns a `TimezoneInfo` whose IANA identifier is exposed by `identifier`. See: https://pub.dev/documentation/flutter_timezone/latest/timezone_info/TimezoneInfo-class.html
