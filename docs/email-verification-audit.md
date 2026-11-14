# Email verification audit and email-code plan

Audited on 14 November 2026: the app code, `firestore.rules`, the git history, and the live
Firebase Auth settings of `hadithdaily-5fc06`. The live check was read-only and printed counts only,
never an address.

## What was decided and built (14 November 2026)

- **Sender:** a dedicated Gmail account, `tayebkalbak@gmail.com`, sending through Gmail's own
  servers with an app password, instead of a domain for now. Readers see the sender name «طيّب قلبك».
  A live test code reached the **Primary** inbox. Moving to a domain later only means changing
  `MAIL_USER` and the SMTP settings in `functions/`.
- **Backend:** Firebase moved to Blaze. Four functions in `functions/src/index.ts` are deployed to
  `us-central1`: `sendEmailCode`, `verifyEmailCode`, `discardUnverifiedAccount`, and
  `cleanupUnverifiedAccounts` (off until `CLEANUP_CREATED_AFTER` is set). Secrets live in Secret
  Manager: `GMAIL_APP_PASSWORD`, `OTP_PEPPER`.
- **App:** a code screen after sign-up and on sign-in for unconfirmed accounts, and a prompt before
  shared actions. Also: an 8-character password minimum, a typo hint, Arabic reset emails, and a
  message for `account-exists-with-different-credential`.
- **Password reset:** by code too (`sendPasswordResetCode`, `resetPasswordWithCode`), from the
  same address and in the same Arabic layout. The reader types the code and a new password in the
  app and is signed in. It gives the same answer whether or not the address has an account. A
  successful reset confirms the address and signs out other devices. Google and Apple accounts get
  a note saying how they sign in. Firebase's own reset link is now used only by the staff
  dashboard.
- **Paste:** a «لصق الرمز» button on both code screens. It reads the clipboard only when tapped.
- **Rules:** `isVerified()` on shared writes, plus the F4 fixes. **Deploy the rules only after the
  app version with the code screen is published.**
- **F3 fixed:** Apple accounts can delete themselves in the app (re-authentication through Apple,
  then the Apple token is revoked before the account goes).
- **Still open from this report:** F6 (staff sign-in), F10 (App Check).

## The short version

1. **The app doesn't verify email addresses at all.** Verification was added on 5 September
   (`5fcc85b`) and removed the same day (`3328140`). Since then, anyone can sign up with any address,
   including one they don't own, and use every feature.
2. **22 of the 23 email/password accounts in production are unverified.** They were created
   between 6 and 76 days ago.
3. **Every email Firebase sends today is likely to land in spam.** It goes out in the default
   English template, from `noreply@hadithdaily-5fc06.firebaseapp.com`, with no sender name and with
   links on `firebaseapp.com`. No custom domain is set up (`customDomainState: NOT_STARTED`). This
   affects password reset now, so a reader who forgets their password may never see the reset email.
4. **An emailed 6-digit code (OTP) is the right fix,** but sending it safely needs a small backend.
   That means moving Firebase to the **Blaze** plan. At this app's size it should cost close to
   nothing, but it needs a card on file.
5. **To keep the emails out of spam, you need your own domain.** `tayebqalbak.com` doesn't exist in
   DNS today, so it is very likely free to register. Gmail addresses can't be used to send app mail.

---

## 1. What I checked

| Area | Where |
|---|---|
| Sign-up, sign-in, password reset | `lib/core/auth/auth_service.dart`, `lib/features/auth/*` |
| When sign-in is asked for | `lib/core/auth/sign_in_gate.dart` |
| Account deletion | `lib/data/services/account_deletion_service.dart`, `lib/features/profile/delete_account_sheet.dart` |
| Dashboard sign-in | `lib/features/dashboard/dashboard_app.dart` |
| Server rules | `firestore.rules` |
| History | `5fcc85b` (verification added), `3328140` (verification removed) |
| Live project | Identity Toolkit config (GET), plus an aggregate count of accounts by provider and verified state |

**Live Auth settings found:**

| Setting | Value | Meaning |
|---|---|---|
| Email enumeration protection | **On** | Good. Sign-in errors don't reveal which addresses have accounts |
| Email sending method | `DEFAULT` | Firebase's shared sender, not yours |
| Custom email domain | `NOT_STARTED` | Mail comes from `firebaseapp.com` |
| Template language | `en` | Reset emails arrive in English; the app never calls `setLanguageCode('ar')` |
| Sender name | not set | Inbox shows `noreply` |
| Action links | `hadithdaily-5fc06.firebaseapp.com/__/auth/action` | Link domain differs from the brand, which spam filters dislike |
| Password policy | not set | Firebase minimum (6 characters) |
| Multi-factor | Disabled | Includes moderator and admin accounts |
| Authorized domains | `localhost`, `firebaseapp.com`, `web.app` | `localhost` is fine for development; remove it before a hardening pass |

**Accounts (33 total):** 22 email/password only, 1 Google plus password, 4 Google only, and **6 with
no sign-in method attached**. Git history has no anonymous sign-in, so those 6 were probably made
from the console or a script. Have a look at them in Firebase console → Authentication → Users.

---

## 2. Findings

Severity is for this app as it is today: a public app with a community feed and a staff dashboard.

| # | Severity | Finding |
|---|---|---|
| F1 | **High** | No email verification anywhere |
| F2 | **High** | Firebase's auth emails are set up in a way that sends them to spam, so password reset doesn't reliably arrive |
| F3 | **High (iOS)** | Readers who signed in with Apple can't delete their account in the app |
| F4 | Medium | The rules accept any email the phone sends for `users/{uid}.email` and `feedbackMessages.userEmail` |
| F5 | Medium | The rules let unverified accounts post, like, report, send feedback and join the weekly board |
| F6 | Medium | Moderator and admin accounts are password-only, with no second factor and no verified-email check |
| F7 | Medium | A display name claimed by an abandoned or fake account stays taken forever |
| F8 | Low | `account-exists-with-different-credential` isn't handled, so the reader sees "unexpected error" |
| F9 | Low | Passwords need only 6 characters; the email check is just `contains('@')`, with no typo hint |
| F10 | Low | No App Check, so anyone holding the public API key can call Firestore directly |
| F11 | Low | The dashboard shows Firebase's raw English error text |
| F12 | Info | Name uniqueness is only enforced at sign-up; `authorName` on posts and `name` on the board are free text |

### F1. No email verification (High)

`signUpWithEmail` creates the account, sets the name, writes `users/{uid}`, claims the username and
lets the reader in. Nothing anywhere reads `emailVerified`, not in the app and not in the rules.

What this allows:

- **Signing up with someone else's address.** The real owner later finds it "already in use".
  Password reset still works for them because it goes to the real inbox, but only if that email
  arrives (see F2).
- **Typos lock people out.** Someone who types `ahmed@gmial.com` gets a working account. The first
  time they forget the password, the reset email goes to an address that doesn't exist and the
  account is lost. Verifying at sign-up catches the typo while they're still on the screen.
- **Throwaway accounts.** Unverified accounts can fill the moderation queue, inflate likes, file
  reports and join the board. Firebase limits sign-ups per IP, but a fresh address costs nothing.
- **Untrustworthy data for staff.** The dashboard's user list and the feedback inbox show addresses
  nobody proved they own. A moderator who replies to feedback may be writing to a stranger.
- **Account pre-hijacking.** This is a known attack: someone registers the victim's address before
  the victim does, then waits for the victim to start using the account. Firebase reduces the risk
  for Gmail addresses that later sign in with Google, but verifying at sign-up closes it properly.

The September version used Firebase's verification **link** and was removed the same day. Its
emails would have hit the same spam problem as F2, which is probably part of why it felt broken.

### F2. Auth emails go to spam (High)

Everything in the live config table points the same way: a shared Firebase sender domain, no sender
name, an English subject (`Reset your password for %APP_NAME%`) going to Arabic readers, and links on
a different domain from the brand. Gmail and Outlook treat that combination as suspicious. This
already hurts password reset today, before any OTP work starts.

You can fix this without the Blaze plan (Phase 0 below). Firebase can send its own emails from your
domain, either through **Customize domain** on the Templates page or through **SMTP settings**
pointing at the email provider described in section 4.

### F3. Apple accounts can't be deleted in the app (High, iOS)

`AccountDeletionService.reauthMethod` returns `unsupported` for `apple.com`. The sheet then tells the
reader to "contact us". App Store guideline 5.1.1(v) requires deleting an account from inside the
app, and Apple expects the Sign in with Apple token to be revoked when that happens. Expect a
rejection on the first iOS review. The fix is to re-authenticate with Apple, delete the data as
today, then call `revokeTokenWithAuthorizationCode`, all from the app.

### F4. The rules trust the email the phone sends (Medium)

- `users/{uid}` create checks the field names but not the value of `email`. A modified client can
  store `ceo@anything.com` as its email, and the dashboard will show it.
- `feedbackMessages` create checks only the length of `userEmail`. Someone can file feedback
  "from" a victim's address, and a moderator replying would then email the victim.
- `users/{uid}.createdAt` accepts any value.

Fix: `email == request.auth.token.email`, `userEmail == request.auth.token.email`, and
`createdAt == request.time`, with matching cases in `tool/verify_rules.py`.

### F5. The rules don't require a verified email (Medium)

Every write rule checks only `request.auth != null`. Once verification exists, add an
`isVerified()` check (`request.auth.token.email_verified == true`) to anything other readers see:
community posts, likes, reports, feedback and board scores. Google and Apple accounts already carry
`email_verified: true`, so this only affects email/password accounts. Leave favourites and the
reading journey open, since they only affect the reader's own data.

### F6. Staff accounts (Medium)

An admin can change roles, delete user records and rewrite every collection. Today that power sits
behind an email and a password, with no second factor. Two cheap improvements:

1. Add Google sign-in to the dashboard and have staff use Google accounts with 2-Step Verification
   turned on.
2. In the rules, require staff to be verified (and optionally signed in with Google):
   `isModerator() && request.auth.token.email_verified == true`.

### F7. Display names held by dead accounts (Medium)

`usernames/{name}` is claimed at sign-up and only released when the account is deleted. An account
nobody verifies keeps its name forever. The cleanup job in the OTP plan releases it.

### F8 to F12 (Low and Info)

- **F8:** add a case to `authErrorMessage` for `account-exists-with-different-credential`. It should
  say this email already has an account, and to sign in with the password or reset it.
- **F9:** raise the client minimum to 8 characters and set the same rule under Authentication →
  Settings → Password policy. Add a "did you mean gmail.com?" hint for the common misspellings.
- **F10:** App Check (Play Integrity on Android, App Attest on iOS, reCAPTCHA for the dashboard).
  Run it in monitor mode first, so old app versions aren't locked out.
- **F11:** route the dashboard's errors through `authErrorMessage`, like the phone app does.
- **F12:** accepted for now, because moderators approve posts before anyone sees them.

**Already in good shape:** enumeration protection is on; the Apple nonce and Google client IDs are
handled correctly; a failed sign-up rolls the account back; the username claim can't be raced;
`secrets/` is git-ignored; integration tests run against the emulator, not production.

---

## 3. The email code (OTP): proposed design

### Why it needs a backend

A code is only secure if the phone **can't** see the right answer or mark itself verified.
Generating the code, storing it, sending the email with a secret API key, and setting
`emailVerified = true` all have to happen on a server. In this project that means **Cloud Functions
for Firebase**, which only deploy on the **Blaze** plan. The free usage allowance is far beyond what
this app uses, so the bill should stay at roughly zero. Still, set a budget alert (section 6).

### Flow

```
Sign-up screen ──► create account (as today) ──► "Enter the code we sent to a…@gmail.com"
                                                    │
                       sendEmailCode (function) ◄───┘   6 digits, valid 10 minutes
                                                    │
     reader types code ──► verifyEmailCode (function) ──► emailVerified = true
                                                    │
                       phone refreshes its token ───┴──► Home (or back to what they were doing)
```

- **Verify after the account exists, not before.** Only a signed-in, brand-new account can ask for a
  code, and only for its own address. A "send a code to any address" endpoint would let anyone use
  your domain to flood strangers' inboxes, which is exactly how a sending domain ends up blocked.
- **Browsing stays open.** The app already lets guests read everything. An unverified reader can keep
  reading. The code screen appears at sign-up, and again at the four points where `requireSignIn` is
  called (favourites, likes, posting, feedback) until they verify.
- **Wrong address:** the code screen has a "change email" option. It deletes the unverified account
  (releasing the name) and returns to the sign-up form with the fields still filled in.
- **Google and Apple sign-ins skip all of this.** Those providers have already verified the address.

### Security rules for the code itself

| Rule | Value |
|---|---|
| Code | 6 digits from a secure random generator (`crypto.randomInt`) |
| Stored as | HMAC-SHA256 with a server-only secret, never the plain code, in `emailCodes/{uid}`. The existing catch-all rule already blocks client access to that collection |
| Expires | 10 minutes, single use, deleted on success |
| Wrong attempts | 5, then the code is void and a new one is needed. The counter goes up *before* comparing, so racing requests can't get extra guesses |
| Comparison | constant-time (`timingSafeEqual`) |
| Bound to | the account **and** the address it was sent to; it fails if the account's email changed in between |
| Resend | 60-second cooldown, at most 5 an hour and 10 a day per account, plus a per-IP cap |
| Logs | never contain the code; addresses are masked (`a…@gmail.com`) |
| Called with | App Check enforced on both functions once App Check is on (F10) |
| On success | Admin SDK sets `emailVerified: true`; the phone calls `getIdToken(true)` so the rules see it straight away |
| Cleanup | a daily job deletes email/password accounts left unverified for 7 days, along with their `users/` doc and username. It applies only to accounts created after launch (see below) |

### The 22 existing unverified accounts

Don't delete them, because some belong to real readers. Recommended: on their next sign-in, they see
the code screen once. Shared actions (posting, liking, feedback) are blocked by the rules until they
verify; their favourites and reading journey keep working. The 7-day cleanup never touches accounts
created before the launch date.

### What changes in the code

| Where | Change |
|---|---|
| `functions/` (new, TypeScript) | `sendEmailCode`, `verifyEmailCode`, `cleanupUnverifiedAccounts`, the email template, rate limits. Emulator mode writes the code to a test-only doc instead of sending mail |
| `lib/features/auth/email_code_screen.dart` (new) | Six boxes, paste support, `AutofillHints.oneTimeCode`, resend countdown, change-email option |
| `auth_service.dart` | `isEmailVerified`, `sendEmailCode()`, `verifyEmailCode()`, `setLanguageCode('ar')` |
| `signup_screen.dart` | Go to the code screen after sign-up; 8-character minimum; typo hint |
| `sign_in_gate.dart` | A signed-in but unverified reader gets the code screen, not a pass |
| `firestore.rules` + `tool/verify_rules.py` | `isVerified()` on shared writes; the F4 fixes; tests for each |
| `integration_test/` | A sign-up → code → verified run on the emulators |
| `web/privacy-policy.html` | Name the email provider as a service we use to send codes |

### Draft of the code email

Written to the voice rules: one idea, no exclamation marks, no emoji, nothing that assumes the
reader's gender. Plain text plus a simple right-to-left HTML version. No images and no links, both
of which help with spam filters.

> **From:** طيّب قلبك ‹hello@mail.tayebqalbak.com›
> **Subject:** رمز تأكيد بريدك في طيّب قلبك: 482913
>
> السلام عليكم،
>
> هذا رمز تأكيد بريدك في طيّب قلبك:
>
> **482913**
>
> الرمز صالح لعشر دقائق، ويُكتب في شاشة التأكيد داخل التطبيق.
>
> إن لم يكن الطلب منك فلا حاجة لفعل شيء، فالحساب الذي لا يُؤكَّد يُحذف تلقائياً.
>
> طيّب قلبك

Putting the code in the subject means it shows in the phone's notification, so most readers never
need to open the email.

---

## 4. The sender address and keeping mail out of spam

### Who creates the mailbox

**You do, and you mostly need a domain rather than a mailbox.** Registering a domain, opening an
email-provider account and upgrading Firebase all need your payment details and your identity, so I
can't do them for you. Everything after that, I can do: the code, the DNS record list, checking each
record once it's live, the templates and the tests.

The app doesn't log into a mailbox to send codes. It sends through an email provider's API, using an
address on your domain. A real inbox is only needed to **receive** replies, and free forwarding to
your Gmail covers that.

### Why not a Gmail address

Gmail addresses can't send app mail through another service. Mail like that fails Gmail's own
sender checks (DMARC), and the email providers won't let you verify `gmail.com` as a sending domain. Mail sent "from"
`tayebqalbak@gmail.com` by the app would bounce or land in spam. So you need your own domain.

### Recommended setup

| Piece | Recommendation | Why |
|---|---|---|
| Domain | `tayebqalbak.com` (matches the app ID `com.prodktstudio.tayebqalbak`). `tayebkalbak.com` also looks free; buy it too only if you want the second spelling to redirect | Not registered in DNS as of today |
| Registrar and DNS | Cloudflare (sells at cost, free DNS) | DNS changes apply in minutes, and Email Routing is free |
| Receiving | Cloudflare Email Routing: `hello@tayebqalbak.com` forwards to your Gmail | Free; replies to the app's mail reach you |
| Sending provider | **Resend** to start. Free plan: 100 emails a day, 3,000 a month | Simple API, also works as SMTP for Firebase's own emails, good deliverability. Move to a paid plan or Amazon SES if sign-ups pass about 70 a day |
| Sending subdomain | `mail.tayebqalbak.com` | Keeps the main domain's reputation separate from app mail |
| From | `طيّب قلبك <hello@mail.tayebqalbak.com>` | A real name and a reply-able address both help with filters |
| Reply-To | `hello@tayebqalbak.com` | Forwards to you |

### DNS records that make mail trusted (you add them, I'll check them)

| Record | Purpose |
|---|---|
| **SPF** (TXT on the sending subdomain, from Resend) | Says which servers may send for the domain |
| **DKIM** (TXT or CNAME, from Resend) | Signs every email so receivers can confirm it's really yours |
| **MX** for the bounce subdomain (from Resend) | Lets bounces return, so the provider can stop sending to dead addresses |
| **DMARC**: `_dmarc.tayebqalbak.com` TXT `v=DMARC1; p=none; rua=mailto:hello@tayebqalbak.com` | Gmail and Yahoo require it from bulk senders and reward it for everyone else. Start at `p=none`; after 2 to 4 clean weeks, change it to `p=quarantine` |
| Firebase domain records (TXT and CNAMEs from the Templates page) | Only if Firebase's own emails use **Customize domain** rather than SMTP |

### Habits that keep mail out of spam

- Send only transactional mail (codes and password reset) from this subdomain. If you ever send
  newsletters, use a different subdomain.
- Keep the email short and in Arabic, with a plain-text version alongside the HTML. No link
  shorteners, images or attachments.
- Keep bounces low: the typo hint (F9) and the resend caps mean the app rarely sends to dead
  addresses.
- Route Firebase's password-reset emails through the same provider (Firebase → Authentication →
  Templates → SMTP settings), so every email the reader gets comes from one trusted domain.
- Before launch, run a test send through mail-tester.com (aim for 10/10) and to Gmail, Outlook,
  Yahoo and iCloud test inboxes.
- Add the domain to Google Postmaster Tools to watch its reputation with Gmail, where most of your
  readers are.

---

## 5. Your to-do list

Steps 1 to 4 can start today and don't depend on each other.

1. **Decide** between the email code (needs Blaze, recommended) and the free fallback: Firebase's
   verification *link*, sent from your domain. Section 7 compares them.
2. **Buy the domain** `tayebqalbak.com`, ideally at Cloudflare.
3. **Turn on Cloudflare Email Routing:** `hello@tayebqalbak.com` → `prodktstudio@gmail.com`.
4. **Firebase console, no code needed:**
   - Project settings → *Public-facing name* → `طيّب قلبك` (this fills `%APP_NAME%` in emails).
   - Authentication → Templates: set the language to Arabic, the sender name to `طيّب قلبك`, and
     Reply-To to `hello@tayebqalbak.com`.
   - Authentication → Settings → Password policy: minimum length 8.
5. **Create a Resend account,** add the domain `mail.tayebqalbak.com`, and paste the records it shows
   into Cloudflare DNS. Tell me when they're in and I'll check each one.
6. **Upgrade Firebase to Blaze,** then in Google Cloud Billing → Budgets, add a **$5** budget with
   email alerts.
7. **Create a sending-only API key in Resend** and store it yourself from the project folder. Paste
   the key into the terminal prompt, not into chat:
   ```bash
   firebase functions:secrets:set RESEND_API_KEY
   ```
8. **Firebase → Authentication → Templates → SMTP settings:** host `smtp.resend.com`, port `465`,
   username `resend`, password = the same API key, sender `hello@mail.tayebqalbak.com`. From then on,
   password-reset emails come from your domain too.
9. **Later, for App Check:** register the app in Firebase → App Check (Play Integrity needs the
   release SHA-256 fingerprint, which is already in Play Console).
10. **Check the 6 accounts with no sign-in method** under Authentication → Users and delete any you
    don't recognise.

---

## 6. What I'll build, in order

| Phase | Needs from you | Contents |
|---|---|---|
| **0: now** | nothing | `setLanguageCode('ar')`; F4 rule fixes plus tests; F8 error message; 8-character minimum and typo hint; dashboard error text; Apple account deletion (F3) |
| **1: email code** | steps 2, 5, 6, 7 | `functions/` with send, verify and cleanup; code screen; sign-in gate; `isVerified()` in the rules; emulator tests; privacy policy line |
| **2: hardening** | steps 8, 9 | Password reset through your domain; App Check (monitor mode, then enforced); staff on Google sign-in with a verified-email check (F6); turn on the cleanup job |

### Expected cost per month at today's size

| Item | Cost |
|---|---|
| Domain | about $10 to $12 a year |
| Cloudflare DNS and Email Routing | free |
| Resend | free up to 100 emails a day |
| Cloud Functions and Firestore on Blaze | within the free allowance: $0 |
| Secret Manager and function image storage | a few cents at most |

---

## 7. Fallback if you'd rather stay on the free Spark plan

Firebase's own **verification link** with your domain (Templates → Customize domain or SMTP), an
Arabic template, and the app checking `emailVerified` after the reader taps the link. It costs
nothing and fixes F1 and F2. The trade-offs: it's a link rather than a code (the reader leaves the
app and comes back), Firebase only lets you edit part of the template, and there is no cleanup job.
Phase 0 and the rule changes are the same in both options.

---

## Sources

- Firebase: [Use a custom domain for Authentication emails](https://firebase.google.com/docs/auth/email-custom-domain)
- Firebase support: [Customizing Authentication email templates](https://support.google.com/firebase/answer/7000714)
- Resend: [Pricing](https://resend.com/pricing), [What is Resend pricing](https://resend.com/docs/knowledge-base/what-is-resend-pricing)
- Brevo alternative (300 emails a day free, Brevo branding on the free plan): [Brevo review 2026](https://dreamlit.ai/blog/brevo-review)
