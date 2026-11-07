import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/community_service.dart';

void main() {
  group('CommunityService.awaitDelivery', () {
    const budget = Duration(milliseconds: 20);

    test('a write the server confirms is delivered', () async {
      expect(
        await CommunityService.awaitDelivery(Future.value(), budget: budget),
        MessageDelivery.confirmed,
      );
    });

    test('a write the server never answers stops the wait', () async {
      final neverAnswered = Completer<void>();

      expect(
        await CommunityService.awaitDelivery(
          neverAnswered.future,
          budget: budget,
        ),
        MessageDelivery.queued,
      );
    });

    test('a rejection in time still reaches the reader', () async {
      await expectLater(
        CommunityService.awaitDelivery(
          Future<void>.error(StateError('denied')),
          budget: budget,
        ),
        throwsStateError,
      );
    });

    test('a rejection after the wait ended does not surface as a crash',
        () async {
      final late = Completer<void>();
      final delivery = await CommunityService.awaitDelivery(
        late.future,
        budget: budget,
      );
      expect(delivery, MessageDelivery.queued);

      late.completeError(StateError('denied'));
      await pumpEventQueue();
    });

    test('the budget matches the other server waits in the app', () {
      expect(CommunityService.sendBudget, const Duration(seconds: 12));
    });
  });
}
