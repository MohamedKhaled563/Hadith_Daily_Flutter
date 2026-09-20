import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/data/services/moderation_service.dart';

/// App Store guideline 1.2 asks a UGC app for two things: a way to report
/// objectionable content, and a way to block an abusive user. Reporting is a
/// Firestore write and belongs to the rules tests; blocking is entirely local,
/// which is exactly why it can be pinned down here.

void main() {
  late ModerationService moderation;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // A singleton, so it carries state between tests unless load() is given a
    // clean disk to re-read — which the mock above has just provided.
    moderation = ModerationService();
    await moderation.load();
  });

  test('nobody is blocked to begin with', () {
    expect(moderation.blockedAuthors, isEmpty);
    expect(moderation.isBlocked('أميرة'), isFalse);
  });

  test('blocking an author hides them, unblocking brings them back', () async {
    await moderation.setBlocked('أميرة', true);
    expect(moderation.isBlocked('أميرة'), isTrue);
    expect(moderation.isBlocked('خالد'), isFalse,
        reason: 'blocking one author must not hide the whole feed');

    await moderation.setBlocked('أميرة', false);
    expect(moderation.isBlocked('أميرة'), isFalse);
    expect(moderation.blockedAuthors, isEmpty);
  });

  test('a block survives a restart', () async {
    await moderation.setBlocked('أميرة', true);

    final stored = (await SharedPreferences.getInstance())
        .getStringList('moderation.blockedAuthors');
    expect(stored, contains('أميرة'),
        reason: 'the block has to reach disk, not just memory');

    // load() replaces the in-memory set with whatever disk holds, so this is
    // the same path a cold start takes.
    await moderation.load();
    expect(moderation.isBlocked('أميرة'), isTrue);
  });

  test('blocking twice is still one block', () async {
    await moderation.setBlocked('أميرة', true);
    await moderation.setBlocked('أميرة', true);
    expect(moderation.blockedAuthors, hasLength(1));
  });

  test('an empty name is not a blockable author', () async {
    // Guards the feed against a post whose author name failed to load hiding
    // every other post whose name also failed to load.
    await moderation.setBlocked('   ', true);
    expect(moderation.blockedAuthors, isEmpty);
  });

  test('the caller cannot mutate the block list behind the service', () async {
    await moderation.setBlocked('أميرة', true);
    expect(
      () => moderation.blockedAuthors.add('خالد'),
      throwsUnsupportedError,
    );
  });

  group('report reasons', () {
    test('every reason has a stable key and Arabic label', () {
      for (final reason in ReportReason.values) {
        expect(reason.key, isNotEmpty);
        expect(reason.label, isNotEmpty);
        expect(
          RegExp(r'^[a-z_]+$').hasMatch(reason.key),
          isTrue,
          reason: 'keys go to the moderator dashboard and must not be Arabic '
              'UI copy that may later be reworded: ${reason.key}',
        );
      }
    });

    test('keys are distinct, so reports can actually be grouped', () {
      final keys = ReportReason.values.map((r) => r.key).toSet();
      expect(keys, hasLength(ReportReason.values.length));
    });

    test('the list covers what a reader of this app would object to', () {
      final keys = ReportReason.values.map((r) => r.key).toList();
      expect(
        keys,
        containsAll(<String>['offensive', 'misattributed', 'spam', 'other']),
        reason: 'misattribution is the one this app cannot omit — a reflection '
            'presented as the Prophet\'s words is its own kind of harm',
      );
    });
  });
}
