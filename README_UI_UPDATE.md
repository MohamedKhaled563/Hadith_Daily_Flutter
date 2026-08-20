# Hadith Daily — UI V6

V6 is the final visual polish pass over V5. It does not add a major feature; it unifies the product language and improves usability across the existing screens.

## UI polish
- Editorial Arabic typography with clearer hierarchy.
- Refined warm neutral / deep green palette for light and dark themes.
- Floating, visually contained bottom navigation.
- Scroll-safe Home layout with pull-to-refresh.
- More intentional daily-status banner after reading today's hadith.
- Less generic Hadith card spacing and proportions.
- Cleaner search empty state and Arabic numeric labels.
- More consistent Favorites copy and numbering.

## Integration
This is a source patch on top of the original repository plus the V2–V5 patches. Merge these files into the repo that already contains the existing data/models/services and the V3/V4/V5 additions.

## Validation
Flutter SDK is not available in the execution environment, so `flutter analyze` / `flutter build` could not be run here. Run `flutter pub get`, `flutter analyze`, and `flutter run` on the target machine.
