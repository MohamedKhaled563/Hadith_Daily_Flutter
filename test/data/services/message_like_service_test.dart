import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/message_like_service.dart';

/// Stands in for one `authStateChanges` listener: replays the current user
/// on listen, then follows every change.
class _FakeAuth {
  _FakeAuth(this.uid);

  String? uid;
  final _changes = StreamController<String?>.broadcast();

  Stream<String?> changes() async* {
    yield uid;
    yield* _changes.stream;
  }

  void signIn(String? next) {
    uid = next;
    _changes.add(next);
  }
}

void main() {
  group('MessageLikeService.followingUser', () {
    test('a cold start with nobody signed in corrects itself at sign-in',
        () async {
      final auth = _FakeAuth(null);
      final seen = <String>[];
      final sub = MessageLikeService.followingUser<String>(
        auth.changes,
        (uid) => Stream.value('likes of $uid'),
      ).listen(seen.add);

      await pumpEventQueue();
      expect(seen, ['likes of null']);

      auth.signIn('reader');
      await pumpEventQueue();
      expect(seen, ['likes of null', 'likes of reader']);

      await sub.cancel();
    });

    test('the same user again does not reopen their stream', () async {
      final auth = _FakeAuth('reader');
      var built = 0;
      final sub = MessageLikeService.followingUser<int>(
        auth.changes,
        (_) => Stream.value(++built),
      ).listen((_) {});

      await pumpEventQueue();
      auth.signIn('reader');
      await pumpEventQueue();
      expect(built, 1);

      await sub.cancel();
    });

    test('a change of user closes the previous stream', () async {
      final auth = _FakeAuth('first');
      final cancelled = <String?>[];
      final sub = MessageLikeService.followingUser<int>(
        auth.changes,
        (uid) {
          late final StreamController<int> inner;
          inner = StreamController<int>(
            onCancel: () => cancelled.add(uid),
          );
          return inner.stream;
        },
      ).listen((_) {});

      await pumpEventQueue();
      auth.signIn('second');
      await pumpEventQueue();
      expect(cancelled, ['first']);

      await sub.cancel();
      expect(cancelled, ['first', 'second']);
    });

    test('a held stream can be listened to twice', () async {
      final stream = MessageLikeService.followingUser<String>(
        _FakeAuth('reader').changes,
        (uid) => Stream.value('likes of $uid'),
      );

      expect(await stream.first, 'likes of reader');
      expect(await stream.first, 'likes of reader');
    });

    test('an error from the user\'s stream reaches the listener', () async {
      final errors = <Object>[];
      final sub = MessageLikeService.followingUser<int>(
        _FakeAuth('reader').changes,
        (_) => Stream<int>.error(StateError('denied')),
      ).listen((_) {}, onError: errors.add);

      await pumpEventQueue();
      expect(errors.single, isA<StateError>());

      await sub.cancel();
    });
  });
}
