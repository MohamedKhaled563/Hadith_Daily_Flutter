import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:hadith_app/data/services/submission_approval_watcher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared between a host and a device entry point — see
/// notification_scheduler_suite.dart for why.
class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockReminderSource extends Mock implements NotificationDataSource {}

/// In-memory stand-in for Firestore, which lets a test decide what the server
/// answers and when a pending message gets decided.
class _FakeSubmissions implements SubmissionDataSource {
  List<ApprovedSubmission> approved = [];
  Object? error;
  int loads = 0;

  /// When set, [loadApproved] blocks on it, parking a check mid-read.
  Completer<void>? gate;

  final decided = StreamController<void>.broadcast();

  @override
  Future<List<ApprovedSubmission>> loadApproved(String uid) async {
    loads++;
    final parked = gate;
    if (parked != null) await parked.future;
    if (error != null) throw error!;
    return List.of(approved);
  }

  @override
  Stream<void> pendingDecided(String uid) => decided.stream;
}

ApprovedSubmission _message(String id) =>
    ApprovedSubmission(id: id, message: 'نص $id');

void submissionApprovalSuite() {
  setUpAll(() {
    registerFallbackValue(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    registerFallbackValue(const NotificationDetails());
  });

  group('SubmissionApprovalWatcher', () {
    late _FakeSubmissions submissions;
    late StreamController<String?> auth;
    late List<List<String>> notified;
    late List<SubmissionApprovalWatcher> started;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      submissions = _FakeSubmissions();
      auth = StreamController<String?>.broadcast();
      notified = [];
      started = [];
    });

    tearDown(() {
      for (final watcher in started) {
        watcher.dispose();
      }
    });

    /// A fresh watcher, which is what a new launch of the app amounts to.
    SubmissionApprovalWatcher launch({
      Future<void> Function(List<ApprovedSubmission>)? notify,
    }) {
      final watcher = SubmissionApprovalWatcher(
        dataSource: submissions,
        uidChanges: () => auth.stream,
        notify: notify ??
            (approved) async =>
                notified.add([for (final s in approved) s.id]),
      )..start();
      started.add(watcher);
      return watcher;
    }

    /// Lets a stream event reach the watcher, then waits out the check it
    /// started.
    Future<void> settle(SubmissionApprovalWatcher watcher) async {
      await pumpEventQueue();
      await watcher.check();
    }

    Future<SubmissionApprovalWatcher> signedIn([String uid = 'reader']) async {
      final watcher = launch();
      auth.add(uid);
      await settle(watcher);
      return watcher;
    }

    test('nothing is read for a signed-out reader', () async {
      final watcher = launch();
      auth.add(null);
      await settle(watcher);

      expect(submissions.loads, 0);
    });

    test('the first check on a device announces nothing already approved',
        () async {
      // A reinstall, a new phone, or the update that ships this feature: none
      // of these should report months-old approvals as news.
      submissions.approved = [_message('old-1'), _message('old-2')];

      await signedIn();

      expect(notified, isEmpty);
    });

    test('a message approved while the app was closed is announced at the '
        'next start', () async {
      submissions.approved = [_message('old')];
      (await signedIn()).dispose();

      submissions.approved = [_message('old'), _message('new')];
      await signedIn();

      expect(notified, [
        ['new']
      ]);
    });

    test('a message approved while the app is running is announced as it '
        'happens', () async {
      final watcher = await signedIn();

      submissions.approved = [_message('live')];
      submissions.decided.add(null);
      await settle(watcher);

      expect(notified, [
        ['live']
      ]);
    });

    test('an approval is only ever announced once', () async {
      final watcher = await signedIn();

      submissions.approved = [_message('once')];
      submissions.decided.add(null);
      await settle(watcher);
      submissions.decided.add(null);
      await settle(watcher);
      watcher.dispose();
      await signedIn();

      expect(notified, hasLength(1));
    });

    test('a rejected or withdrawn message announces nothing', () async {
      final watcher = await signedIn();

      // It left the pending list without joining the approved one.
      submissions.decided.add(null);
      await settle(watcher);

      expect(notified, isEmpty);
    });

    test('several approved at once share one notification', () async {
      (await signedIn()).dispose();

      submissions.approved = [_message('a'), _message('b'), _message('c')];
      await signedIn();

      expect(notified, [
        ['a', 'b', 'c']
      ]);
    });

    test('a failed read is retried rather than losing the approval', () async {
      final watcher = await signedIn();

      submissions.approved = [_message('late')];
      submissions.error = StateError('offline');
      submissions.decided.add(null);
      await settle(watcher);
      expect(notified, isEmpty);

      submissions.error = null;
      await watcher.check();

      expect(notified, [
        ['late']
      ]);
    });

    test('a notification that fails to show is tried again next time',
        () async {
      (await signedIn()).dispose();
      submissions.approved = [_message('retry')];

      final failing = launch(notify: (_) async => throw StateError('plugin'));
      auth.add('reader');
      await settle(failing);
      failing.dispose();
      expect(notified, isEmpty);

      await signedIn();

      expect(notified, [
        ['retry']
      ]);
    });

    test('each account on a device keeps its own record', () async {
      submissions.approved = [_message('mine')];
      final watcher = await signedIn('first');

      auth.add('second');
      await settle(watcher);
      expect(notified, isEmpty, reason: 'first check for the second account');

      submissions.approved = [_message('mine'), _message('theirs')];
      auth.add('first');
      await settle(watcher);

      expect(notified, [
        ['theirs']
      ]);
    });

    test('signing out during a read announces nothing', () async {
      final watcher = await signedIn();

      submissions.approved = [_message('stale')];
      final gate = submissions.gate = Completer<void>();
      submissions.decided.add(null);
      await pumpEventQueue();

      auth.add(null);
      await pumpEventQueue();
      gate.complete();
      await watcher.check();

      expect(notified, isEmpty);
    });

    test('overlapping checks announce a message once', () async {
      final watcher = await signedIn();

      submissions.approved = [_message('race')];
      final gate = submissions.gate = Completer<void>();
      final first = watcher.check();
      final second = watcher.check();
      gate.complete();
      await Future.wait([first, second]);

      expect(notified, hasLength(1));
    });
  });

  group('approvalNotificationText', () {
    test('one message quotes it, without a trailing full stop', () {
      final text = approvalNotificationText(const [
        ApprovedSubmission(id: 'a', message: 'الكلمة الطيبة صدقة.'),
      ]);

      expect(text.title, 'قُبلت رسالتك، جزاك الله خيراً');
      expect(text.body, 'الكلمة الطيبة صدقة');
    });

    test('several are counted, in Arabic digits', () {
      final text = approvalNotificationText([_message('a'), _message('b')]);

      expect(text.title, 'قُبلت رسائلك، جزاك الله خيراً');
      expect(text.body, 'عدد الرسائل المقبولة: ٢');
    });
  });

  group('approval notification routing', () {
    late _MockPlugin plugin;
    late NotificationScheduler scheduler;

    setUp(() {
      plugin = _MockPlugin();
      scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _MockReminderSource(),
      );
      when(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);
      when(() => plugin.show(any(), any(), any(), any(),
          payload: any(named: 'payload'))).thenAnswer((_) async {});
    });

    void launchedBy(String? payload) {
      when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
        (_) async => NotificationAppLaunchDetails(
          payload != null,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: payload,
          ),
        ),
      );
    }

    test('shows outside the reminder ids, which reschedule cancels', () async {
      await scheduler.showSubmissionApproved(title: 'عنوان', body: 'نص');

      final id = verify(() => plugin.show(captureAny(), 'عنوان', 'نص', any(),
              payload: NotificationScheduler.submissionApprovedPayload))
          .captured
          .single as int;
      expect(id, NotificationScheduler.submissionApprovedId);
      expect(id, greaterThan(27));
    });

    test('a live tap goes to its own signal, and a reminder tap to its own',
        () async {
      await scheduler.showSubmissionApproved(title: 'عنوان', body: 'نص');
      final onTap = verify(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                captureAny(named: 'onDidReceiveNotificationResponse'),
          )).captured.single as DidReceiveNotificationResponseCallback;

      final approvals = NotificationScheduler.submissionApprovalTapped.value;
      final reminders = NotificationScheduler.notificationTapped.value;

      onTap(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: NotificationScheduler.submissionApprovedPayload,
      ));
      expect(NotificationScheduler.submissionApprovalTapped.value,
          approvals + 1);
      expect(NotificationScheduler.notificationTapped.value, reminders);

      onTap(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'some-reminder-doc-id',
      ));
      expect(NotificationScheduler.submissionApprovalTapped.value,
          approvals + 1);
      expect(NotificationScheduler.notificationTapped.value, reminders + 1);
    });

    test('a cold start from an approval does not count as a reminder launch',
        () async {
      // It would otherwise mark today's message as opened and land on it.
      launchedBy(NotificationScheduler.submissionApprovedPayload);

      expect(await scheduler.wasLaunchedBySubmissionApproval(), isTrue);
      expect(await scheduler.wasLaunchedByNotification(), isFalse);
    });

    test('a cold start from a reminder stays a reminder launch', () async {
      launchedBy('some-reminder-doc-id');

      expect(await scheduler.wasLaunchedByNotification(), isTrue);
      expect(await scheduler.wasLaunchedBySubmissionApproval(), isFalse);
    });

    test('an ordinary launch is neither', () async {
      launchedBy(null);

      expect(await scheduler.wasLaunchedByNotification(), isFalse);
      expect(await scheduler.wasLaunchedBySubmissionApproval(), isFalse);
    });
  });
}
