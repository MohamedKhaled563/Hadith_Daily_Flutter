import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion and touch feedback, in one place.
///
/// Two problems this fixes. First, reduce-motion was honoured in exactly one
/// widget — the home screen's heart circle — while the splash's halo and
/// heartbeat, the loading overlay's rotating ring and the like button's pop
/// all ignored it. A reader who has asked their phone to stop animating
/// things was still getting four looping controllers. Second, there was no
/// haptic feedback anywhere in the app at all, which for something whose
/// primary gesture is pressing a pulsing heart is the difference between a
/// screen and an object.
extension AppMotion on BuildContext {
  /// Whether the reader has asked the OS to reduce motion.
  ///
  /// Prefer this over reading [MediaQuery] directly, so honouring it is a
  /// one-word change at the call site and easy to grep for.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// A duration that collapses to zero under reduce-motion, so an implicit
  /// animation becomes an instant state change rather than a slow one.
  Duration motion(Duration duration) =>
      reduceMotion ? Duration.zero : duration;
}

/// The app's motion scale. Three speeds, each with a job, so twelve different
/// hand-picked millisecond values don't accumulate across twelve files.
class AppDurations {
  const AppDurations._();

  /// State flips on a control the finger is already on: a tab selecting, a
  /// toggle, a colour change.
  static const control = Duration(milliseconds: 180);

  /// Content arriving or leaving: a tab's body, a sheet's contents.
  static const content = Duration(milliseconds: 260);

  /// Ambient, looping motion — the breath of the thing.
  static const ambient = Duration(milliseconds: 4200);

  static const curve = Curves.easeOutCubic;
}

/// Touch feedback, named for what happened rather than how strong it is.
///
/// Wrapped rather than calling [HapticFeedback] directly so the app's idea of
/// "a thing was saved" stays one decision, and so every call site reads as
/// intent. All of these are no-ops on a device without a vibrator, and none
/// of them throws.
class AppHaptics {
  const AppHaptics._();

  /// Moving between peers: a tab, a page in a pager, a segment in a toggle.
  static void selection() => HapticFeedback.selectionClick();

  /// A light, affirmative touch: tapping the heart, opening a message.
  static void tap() => HapticFeedback.lightImpact();

  /// Something is now kept, or no longer kept: a bookmark, a like.
  static void toggle() => HapticFeedback.selectionClick();

  /// A real outcome landed: a post published, an account created.
  static void success() => HapticFeedback.mediumImpact();

  /// Something was refused: a validation error, a failed submit.
  ///
  /// Deliberately the same weight as [success] rather than a heavier buzz —
  /// this app tells someone their reflection needs a hadith attached, not
  /// that they have lost a level.
  static void warning() => HapticFeedback.mediumImpact();
}
