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
| `test/suites/submission_approval_suite.dart` | `test/data/services/submission_approval_watcher_test.dart` | `integration_test/submission_approval_test.dart` |

| `test/suites/journey_suite.dart` | `test/data/journey/journey_test.dart` | `integration_test/journey_test.dart` |
| `test/suites/regression_suite.dart` | `test/regression_test.dart` | `integration_test/regression_test.dart` |

`integration_test/journey_reading_flow_test.dart` drives the reading screen
against the real clock, and `integration_test/journey_firestore_test.dart` runs
the journey store through the real SDK and `firestore.rules` on the local
Firebase emulators — see that file for how to start them. Run these two one
file at a time.

`integration_test/ui_suite_test.dart` walks the journey as a reader meets it,
with real taps on real screens, including every screen at three sizes, in both
themes, at two text sizes. It and the regression suite point Firebase at a demo
project, so neither can touch the live one.

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

## Verifying the notification's status-bar icon

`ActiveNotification` does not expose the small icon, so the suite can only
assert that the drawable *resolves* (a missing one makes `show()` throw
`invalid_icon`). To confirm *which* drawable Android actually used, read it
back from the system while a notification is showing:

```bash
adb -s <device-id> shell dumpsys notification --noredact | grep -A18 tayebqalbak | grep icon
```

That prints something like:

```
icon=Icon(typ=RESOURCE pkg=com.prodktstudio.tayebqalbak id=0x7f080082)
```

Resolve the id against the built APK:

```bash
aapt2 dump resources build/app/outputs/flutter-apk/app-debug.apk | grep 0x7f080082
```

It must come back as `drawable/ic_stat_notify` — the dedicated white
silhouette. If it ever resolves to `mipmap/ic_launcher`, the adaptive
launcher icon is being used as the small icon again and Android will render
it as a white or grey block in the status bar.

## Firebase emulators

Nothing in `lib/` talks to the emulators, so a device test that does has to
wire them up itself, and it leaves something behind. Firestore names its
on-device cache after the app and the project, not the host it read from:

```
firestore.[DEFAULT].hadithdaily-5fc06.(default)
```

An emulator started under the real project id therefore fills the same cache
the real app reads, and that cache survives `flutter run`, which updates the
app in place. That is how two seeded test posts turned up as the emulator's
messages of the day weeks after the run that seeded them. So after any run
against the emulators:

```bash
adb -s <device-id> shell pm clear com.prodktstudio.tayebqalbak
```

Seed Arabic from a UTF-8 file (`curl --data-binary @seed.json`), never inline
in a `curl -d` argument. On a Windows machine whose ANSI code page has no
Arabic (1252 here), the argument reaches curl with every letter already `?`.

## رحلتي for several readers

`integration_test/ruhlati_e2e_test.dart` runs three readers and a moderator
on one phone against the local emulators and the real `firestore.rules`:

1. three readers sign up, each starting with nothing;
2. one reads three days running, memorizes and reviews, and every day is in
   the database;
3. after a cold start her numbers, steps and memorizing come back from the
   database;
4. a second reader on the same phone sees only his own journey;
5. the rules refuse reading or writing another reader's journey or entry;
6. each joins the weekly board under a nickname; the rules refuse a longer
   name, more points than a week allows, unknown fields and other readers'
   entries;
7. the moderator publishes from the dashboard and every reader sees it;
8. a reader renames from the board screen and the database follows;
9. leaving removes the entry, and deleting an account leaves nothing of it
   while the others are untouched.

```bash
firebase emulators:exec --only firestore,auth --project demo-journey   "flutter test integration_test/ruhlati_e2e_test.dart -d <emulator-id>"
```

It is part of `tool/e2e_suite.ps1`. Clear the app's data on the emulator
afterwards, as above.

## On a real phone that holds real data

Never `flutter test` there: an integration run reinstalls the app and
uninstalls it when it ends, and the reader's data goes with it. Install the
release build with `adb install -r`, which keeps the data, then run the
read-only check, which drives the installed app through adb by its
accessibility labels and screenshots every step:

```bash
powershell -ExecutionPolicy Bypass -File tool/phone_journey_check.ps1 -Serial <adb-serial>
```

## Time-dependent tests

The scheduler takes an injectable clock (`NotificationScheduler.test(clock:)`)
and every suite pins it, so assertions like "23:59 is still ahead" are fixed
rather than true-most-of-the-day. Only `notification_device_test.dart` still
touches the real clock, and only because AlarmManager does: it skips its
scheduling checks in the last two minutes before midnight, when a 23:59
target stops being in the future for real.
