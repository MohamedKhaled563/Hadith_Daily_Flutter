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

Two separate things bite here, and they produce the *same* error message:

```
Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
```

**1. "Install via USB" turned off.** Settings → Additional settings →
Developer options → **Install via USB** (التثبيت عبر USB). Needs a
signed-in Xiaomi account and cannot be toggled over adb, so turn it on
physically. While there, also enable **USB debugging (Security settings)**,
which is what lets a test run grant permissions and simulate input.

**2. The per-install confirmation dialog** — this is the one that bites on
every run, and it is easy to misdiagnose as (1). Even with "Install via USB"
on, MIUI raises
`com.miui.securitycenter/.permcenter.install.AdbInstallActivity` for every
adb install, and the countdown sits on its **reject** button ("رفض (٨)").
Ignoring it does not mean "ask me later"; it refuses the install about eight
seconds later with the message above. `flutter test integration_test`
reinstalls once per test file, so an unattended run fails on the second file.

Two details make it awkward to automate:

* The dialog never becomes `mCurrentFocus`. It shows up only in the full
  `dumpsys window windows` list, so focus-based detection never sees it.
* Its "تذكر اختياري" (remember my choice) checkbox does **not** persist an
  *accept* for adb installs on MIUI 12.5 — verified by ticking it and watching
  the dialog return on the very next install. There is no one-time setting to
  flip.

**Do not tick "تذكر اختياري".** The box applies to whichever outcome the
dialog ends on, and this dialog ends on *reject* by itself. Tick it and lose
that race once and MIUI stores a permanent deny: every later install then
fails instantly with `INSTALL_FAILED_USER_RESTRICTED` and no visible dialog.
To recover, toggle **Install via USB** off and back on in Developer options.

So run the watcher in a second terminal for the duration of a device run:

```bash
pwsh tool/miui_auto_accept_install.ps1 -Serial <device-id>
```

With that running, the full suite passes unattended on the phone.

## Time-dependent tests

The scheduler takes an injectable clock (`NotificationScheduler.test(clock:)`)
and every suite pins it, so assertions like "23:59 is still ahead" are fixed
rather than true-most-of-the-day. Only `notification_device_test.dart` still
touches the real clock, and only because AlarmManager does: it skips its
scheduling checks in the last two minutes before midnight, when a 23:59
target stops being in the future for real.
