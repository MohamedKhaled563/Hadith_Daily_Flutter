# Publishing طيّب قلبك to Google Play

A step-by-step runbook for the first release, written against the actual
state of this repo rather than a generic checklist. Android only; iOS is not
in scope yet.

`android/app/build.gradle` refers to "the launch checklist" — this is it.
Keep the two references in that file in step with this filename if it ever
moves; they are what a failing release build points people at.

---

## Where things stand

Verified on 2026-09-23.

| | State |
| --- | --- |
| `applicationId` | `com.prodktstudio.tayebqalbak` |
| `versionName` / `versionCode` | `1.0.0` / `1` (from `pubspec.yaml`'s `version: 1.0.0+1`) |
| `minSdk` / `targetSdk` | 24 / 36 — Play compliant |
| Permissions | `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, plus benign plugin ones |
| `SCHEDULE_EXACT_ALARM` | Deliberately **not** declared — see `AndroidManifest.xml` |
| In-app account deletion | Present (`account_deletion_service.dart`) |
| UGC safety | Reporting + per-device author blocking + moderator approval queue |
| Admin dashboard | Separate entrypoint (`lib/main_dashboard.dart`), not in the phone app |
| Firebase project | `hadithdaily-5fc06` |
| Legal text | `site/` — privacy, terms and account deletion, served by Firebase Hosting |
| Release signing | **Missing** — no `android/key.properties` |

Two blockers: **signing** (step 1) and **hosting the privacy policy**
(step 4). Everything else is Console paperwork.

---

## 1. Create the upload keystore — only you can do this

This creates your app's permanent release identity and its passwords. Do it
yourself; do not let anyone else (including an assistant) generate it or
hold the passwords.

```bash
keytool -genkey -v -keystore "%USERPROFILE%\tayeb-qalbak-upload.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` is at
`C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot\bin\keytool.exe`
if it is not on your PATH.

It will ask for a keystore password, a key password, and your name and
organisation. Use a real password manager entry for both passwords.

> **Back this file up now, in two places.** If you lose it *and* you are not
> enrolled in Play App Signing, you can never update this app again — you
> would have to publish under a new package name and lose every install and
> review. Enrolling in Play App Signing (step 6) makes a lost upload key
> recoverable, which is why the next step assumes you will.

Keep the `.jks` **outside** this repository. `android/key.properties` is
gitignored, but the keystore itself should not live in the project folder at
all.

## 2. Point the build at it

Create `android/key.properties` (gitignored — it will not be committed):

```properties
storePassword=<the keystore password>
keyPassword=<the key password>
keyAlias=upload
storeFile=C:/Users/Mohamed Khaled/tayeb-qalbak-upload.jks
```

Use forward slashes in `storeFile`, even on Windows.

`android/app/build.gradle` picks this up automatically. Nothing else to
change.

## 3. Build and verify the release bundle

Play takes an `.aab`, not an `.apk`.

```bash
flutter build appbundle --release
```

If `key.properties` is missing or wrong, the build **fails on purpose** with
a message saying so — that guard exists precisely so a debug-signed bundle
never reaches the Console.

Then verify what you are about to upload:

```bash
pwsh tool/verify_release_apk.ps1
```

> **Do not skip this.** Release builds run the resource shrinker and debug
> builds do not, so a whole class of breakage is invisible to every test in
> this repo — including the on-device ones. Exactly that happened to the
> notification icon: the shrinker stripped `ic_stat_notify`, every reminder
> failed to schedule with `invalid_icon`, and all 69 tests still passed. The
> script checks the resources the app loads by name.

Note the script checks the APK, so build one too when you want that check:
`flutter build apk --release`. The AAB and APK share the same shrinker
configuration.

Confirm the bundle is signed with your key, not the debug key:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner must be you — **not** `CN=Android Debug`.

## 4. Host the legal pages

Play requires a publicly reachable privacy-policy URL, and so does App
Store Connect. The pages live in `site/`, which is what Firebase Hosting
serves:

- `site/index.html` — a small landing page linking the other three
- `site/privacy-policy.html`
- `site/terms-of-use.html`
- `site/delete-account.html` (see step 5)

```bash
firebase deploy --only hosting
```

They then live at:

- `https://hadithdaily-5fc06.web.app/privacy-policy.html`
- `https://hadithdaily-5fc06.web.app/terms-of-use.html`
- `https://hadithdaily-5fc06.web.app/delete-account.html`

> **This used to serve the app, and that was a problem.** `firebase.json`
> previously pointed `hosting.public` at `build/web` with a rewrite of
> `**` to `/index.html`. Two things followed from that. A `flutter build
> web` run against `lib/main_dashboard.dart` put the *moderator
> dashboard's* login at the project's public root — the same URL handed
> to both app stores. And because the rewrite caught every unmatched
> path, a missing legal page never 404'd; it silently served the app
> shell, so the URL looked alive while the file did not exist.
>
> Both are fixed by serving `site/` as plain static files with no
> rewrite. The dashboard is no longer hosted at all — run it locally:
>
> ```bash
> flutter run -d chrome -t lib/main_dashboard.dart
> ```
>
> Note that `flutter build web -t lib/main.dart` does **not** undo the
> first problem on its own: `-t` only picks the Dart entrypoint, while
> `web/index.html` and `web/manifest.json` are copied verbatim and are
> both still branded as the dashboard.

Whichever host you use, open each URL in a private window and confirm
you see the page itself — not the app.

## 5. Account deletion request page

Play requires apps with accounts to offer **both**:

1. In-app deletion — done (`delete_account_sheet.dart`).
2. A **web page** where someone can request deletion without installing
   the app — `site/delete-account.html`.

The page is written and deploys with the rest of `site/`. Before you
deploy it, replace the placeholder contact address in it: it ships with
a visible `[ضع هنا بريد التواصل]` marker rather than a guessed address,
because Play rejects the page without a working contact, and whatever
address goes there is published to anyone who opens the page.

Give the Console that URL under Data safety → Account deletion.

## 6. Create the app in Play Console

1. Google Play Console → **Create app**
   - App name: `طيّب قلبك`
   - Default language: Arabic
   - App or game: App
   - Free or paid: Free
2. **App integrity → Play App Signing: opt in.** Do this before your first
   upload. It is what makes a lost upload key recoverable.
3. Upload the `.aab` to the **Internal testing** track first (step 9), not
   straight to Production.

## 7. Store listing

Assets you need to produce:

| Asset | Spec |
| --- | --- |
| App icon | 512×512 PNG, 32-bit |
| Feature graphic | 1024×500 PNG/JPG, no alpha |
| Phone screenshots | At least 2, 16:9 or 9:16, min 320px on the short side |
| Short description | ≤ 80 characters |
| Full description | ≤ 4000 characters |

Screenshots worth taking: the home hero, a daily message card, the
day-complete panel, the community feed, and the settings drawer showing the
reminder times.

Write the listing in Arabic — it is an Arabic-first app and the Console's
default language is set to Arabic in step 6.

## 8. Content rating, data safety and audience

**Content rating questionnaire.** Declare that the app carries
user-generated content. It is a religious-content app with no violence,
sexuality, gambling or purchases.

**Target audience.** If you select any age band under 13 you inherit the
Families policy, which is a significantly heavier compliance burden. Unless
you specifically want children as an audience, choose 13+.

**Data safety form.** Declare honestly what this app actually does:

| Collected | Why | Notes |
| --- | --- | --- |
| Email address | Account management | Firebase Auth / Google Sign-In |
| Name | Account management | Display name on community posts |
| User-generated content | App functionality | Community messages |
| App interactions | Analytics/functionality | Firestore reads/writes |

- Data is encrypted in transit (Firestore/HTTPS): **yes**.
- Users can request deletion: **yes** — give the step 5 URL.
- Data shared with third parties: **no** (Firebase is a processor, not a
  third-party share).

Answer this form carefully. A false declaration is one of the more common
reasons for enforcement after launch.

## 9. Internal testing first — do not skip

Create an **Internal testing** release, add your own accounts as testers,
and install from the Play link rather than side-loading.

This is the only way to catch problems that only appear in a
Play-distributed, Play-signed build. Test specifically:

- **Reminders actually arrive.** Set one a few minutes out, lock the phone,
  and leave it. On MIUI/Xiaomi the Autostart restriction is the single most
  likely real-world failure, and no code change fixes it — the app's own tip
  sheet points readers at it.
- Tapping a reminder opens today's message.
- Google Sign-In works with the **Play-signed** certificate. This is a
  classic first-release failure: if Play App Signing re-signs your bundle,
  the SHA-1 changes, and sign-in breaks unless that new SHA-1 is added to
  the Firebase project. Copy the SHA-1 from Console → App integrity → App
  signing, and add it under Firebase → Project settings → Your apps →
  Android → Add fingerprint. Then re-download `google-services.json` if it
  changed.
- Posting a community message, reporting one, and blocking an author.
- Deleting an account.

## 10. Production rollout

Once internal testing is clean:

1. Promote the release to **Production**.
2. Start at a **staged rollout** (10–20%), not 100%. You can halt a staged
   rollout; you cannot un-ship a full one.
3. Watch Console → Quality → Android vitals for crashes and ANRs for a few
   days before going to 100%.

First review typically takes a few days and can take longer for a brand new
developer account.

---

## Releasing an update later

1. Bump `version:` in `pubspec.yaml` — e.g. `1.0.1+2`. The part after `+`
   is the `versionCode` and **must increase** on every upload.
2. `flutter build appbundle --release`
3. `pwsh tool/verify_release_apk.ps1` (after also building the APK)
4. Upload to Internal testing, sanity-check, then promote.

## Things to keep in mind

- **Firestore rules are the real security boundary.** Deploy them with
  `firebase deploy --only firestore:rules` and confirm the deployed version
  matches `firestore.rules` in this repo.
- **`flutter_local_notifications` is on 18.0.1; 22.x is current.** Not a
  launch blocker, but four majors of Android behaviour changes is worth
  planning for.
- **Coverage is two Android devices** (a Redmi Note 8 Pro on Android 11 and
  an API 37 emulator). Internal testing on a wider spread is the cheapest
  way to widen that.
- **Never commit `key.properties` or the `.jks`.** The former is gitignored;
  the latter should not be in the project folder at all.
