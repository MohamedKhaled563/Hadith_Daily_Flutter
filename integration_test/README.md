# Device tests

These run the project's test suites **inside a real app process on a real
device or emulator** rather than on the host.

```bash
flutter test integration_test -d <device-id>      # everything
flutter test integration_test/notification_scheduler_test.dart -d <device-id>
```

`flutter devices` lists the ids.

## Why these exist alongside `test/`

Two reasons, and the first is mundane:

1. **The host runner does not work on every machine.** At least one
   development machine here has a Windows Application Control policy that
   refuses to launch `flutter_tester.exe`, so `flutter test` cannot run at
   all — it fails with `An Application Control policy has blocked this file`
   before a single test loads. The device runner does not use
   `flutter_tester.exe`.

2. **This feature is mostly platform-channel work.** Every historical bug in
   the notification scheduler — the bundled-tzdata vs. real-offset mismatch,
   the missing `flutter_local_notifications` manifest receivers, `cancelAll()`
   dismissing the shade — was invisible to a mocked host test and only ever
   showed up on a device.

The shared suite bodies live in `test/suites/` and are called from both
entry points, so there is one copy of each test:

| Suite | Host entry | Device entry |
| --- | --- | --- |
| `test/suites/notification_scheduler_suite.dart` | `test/data/services/notification_scheduler_test.dart` | `integration_test/notification_scheduler_test.dart` |
| `test/suites/notification_lifecycle_suite.dart` | `test/data/services/notification_lifecycle_test.dart` | `integration_test/notification_lifecycle_test.dart` |

`integration_test/notification_device_test.dart` has no host counterpart on
purpose — it drives the **real** `flutter_local_notifications` plugin against
real AlarmManager and the real notification shade, which only means anything
on a device.

## Android: grant POST_NOTIFICATIONS first

On API 33+ the scheduler asks for `POST_NOTIFICATIONS`, and in a test run
there is nobody to tap the system dialog — the run simply hangs on it (one
observed run sat there for 8m44s). Grant it before starting:

```bash
adb -s <device-id> shell pm grant com.prodktstudio.tayebqalbak android.permission.POST_NOTIFICATIONS
```

Note that the harness reinstalls the app on each run, which clears runtime
grants again, so re-run that command per session (or drive the dialog).

## Xiaomi / MIUI devices

MIUI gates USB installs behind **Settings → Additional settings → Developer
options → Install via USB**, which needs a signed-in Xiaomi account and
cannot be toggled over adb. When it is off, every install path fails with:

```
Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
```

`adb install`, `pm install` from `/data/local/tmp`, and a staged
`install-create`/`install-write`/`install-commit` session all hit the same
gate — it is enforced at commit time by MIUI's own security service. Turn
that setting on physically before running the device tests on such a phone.

## Time-dependent tests

The scheduler takes an injectable clock (`NotificationScheduler.test(clock:)`)
and every suite pins it, so assertions like "23:59 is still ahead" are fixed
rather than true-most-of-the-day. Only `notification_device_test.dart` still
touches the real clock, and only because AlarmManager does: it skips its
scheduling checks in the last two minutes before midnight, when a 23:59
target stops being in the future for real.
