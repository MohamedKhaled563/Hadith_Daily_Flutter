import 'package:flutter/foundation.dart';

import '../../data/models/hadith.dart';

/// Lets a screen deep in the stack send the reader to a home tab, the same
/// way NotificationScheduler.notificationTapped does for a tapped reminder.
class JourneyLinks {
  const JourneyLinks._();

  /// A hadith the reader wants to write about. HomeScreen brings up the
  /// writing tab and AddMessageScreen selects this hadith. Goes back to null
  /// at once, so asking for the same hadith twice still notifies.
  static final ValueNotifier<Hadith?> writeAbout = ValueNotifier<Hadith?>(null);

  static void openWriting(Hadith hadith) {
    writeAbout.value = hadith;
    writeAbout.value = null;
  }
}
