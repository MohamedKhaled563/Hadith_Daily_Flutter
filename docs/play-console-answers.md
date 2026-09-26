# Play Console — the exact answers for طيّب قلبك

Every answer below is traceable to a call site in this repo, not to a
template. Where a form offers a tempting shortcut that would be wrong, the
wrong option is named so you don't pick it by accident.

Verified against the code on 26 September 2026.

---

## Data safety

Play asks this in two passes: first *which* data types you collect, then
*why*, *whether it is linked to the user*, and *whether it is optional*.

### Overview questions

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** | Account creation stores email and display name. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Firestore and Firebase Auth are HTTPS end to end; the app makes no other network calls. |
| Do you provide a way for users to request that their data be deleted? | **Yes** | In-app under الإعدادات، plus the web page below. |
| Deletion request URL | `https://hadithdaily-5fc06.web.app/delete-account.html` | Live and verified. |

### Data types — declare exactly these four

**1. Personal info → Email address**
- Collected: **Yes** · Shared: **No**
- Processed ephemerally: **No** (stored in `users/{uid}`)
- Required or optional: **Required** (needed to create an account)
- Purpose: **App functionality**, **Account management**
- Linked to the user: **Yes**

**2. Personal info → Name**
- Collected: **Yes** · Shared: **No**
- Required or optional: **Required**
- Purpose: **App functionality**, **Account management**
- Linked to the user: **Yes**
- Note: the display name is shown publicly beside community posts. That is
  not a separate declaration, but it is worth knowing if Play queries it.

**3. Messages → Other in-app messages**
- Collected: **Yes** · Shared: **No**
- Required or optional: **Optional** (posting is voluntary)
- Purpose: **App functionality**
- Linked to the user: **Yes**
- Covers `communityMessages` (public posts) and `feedbackMessages`
  (private messages to the moderators).

**4. App activity → Other user-generated content**
- Collected: **Yes** · Shared: **No**
- Required or optional: **Optional**
- Purpose: **App functionality**
- Linked to the user: **Yes**
- Covers `favorites` and `likes` — both keyed by the reader's uid.

### Do NOT declare these

- **Location** — never requested, no plugin for it.
- **Device or other IDs** — `device_info_plus` reads the manufacturer and
  brand string once, in memory, to decide the wording of the
  notification-reliability tip. It is never stored and never transmitted.
  Play's guidance treats that as not collected.
- **Analytics / Crash logs / Diagnostics** — no `firebase_analytics`, no
  Crashlytics, no ad SDK anywhere in `pubspec.yaml`.
- **Photos, Contacts, Calendar, Audio, Files** — none.
- **Approximate or precise location** — none.

If you later add Firebase Analytics or Crashlytics, this form must be
revisited before that release ships.

---

## Content rating questionnaire

Answer as an **app** (not a game). Category: **Reference, News, or
Educational**.

| Question area | Answer |
| --- | --- |
| Violence, sexuality, profanity, drugs, gambling | **No** to all |
| Does the app allow users to interact or exchange content? | **Yes** |
| Can users share their own content publicly? | **Yes** — community posts |
| Do users share location with other users? | **No** |
| Does the app contain user-generated content? | **Yes** |
| Is the app's primary purpose social networking? | **No** — it is a daily reading app with a community section |

When asked how user-generated content is handled, the app genuinely does
all three, so say so:

1. **Pre-moderation** — every community post enters an approval queue and
   is not visible to readers until a moderator approves it.
2. **In-app reporting** — every post carries a report action
   (`contentReports`).
3. **Blocking** — readers can block an author; blocked authors' posts are
   filtered out on-device.

---

## Target audience and content

| Question | Answer | Why |
| --- | --- | --- |
| Target age groups | **18 and over** | Do **not** tick any under-18 band. |
| Is your app designed for children? | **No** | Ticking yes pulls the app into the Families policy programme, which brings a far stricter review, an ads-and-SDK audit, and a separate content rating. There is no reason to opt into it. |
| Does the app appeal to children? | **No** | |

The privacy policy already states the app is not directed at under-13s.

---

## Ads

| Question | Answer |
| --- | --- |
| Does your app contain ads? | **No** |

There is no ad SDK in the project. Answering yes would put an "Ads" badge
on your listing for no reason.

---

## Government apps / Financial features / Health

**No** to all. None apply.

---

## Store listing copy

Set the default language to **Arabic**, then paste these.

### App name (30 characters max)

```
طيّب قلبك
```

### Short description (80 characters max)

```
رسالة يومية من الأربعين النووية، وتأمل هادئ يطيّب قلبك كل صباح ومساء.
```

### Full description (4000 characters max)

```
«طيّب قلبك» تطبيق هادئ للتأمل اليومي في أحاديث الأربعين النووية للإمام النووي رحمه الله.

في كل يوم رسالة واحدة: حديث نبوي مع شرح ميسّر وتأمل قصير يربطه بحياتك. لا إشعارات مزعجة، ولا محتوى لا نهائي يستهلك وقتك — رسالة واحدة تقرؤها في دقيقة، وتبقى معك بقية اليوم.

• الأربعون النووية كاملة
اقرأ الأحاديث الأربعين بنصّها وشرحها، مرتّبة ومفهرسة، متاحة كاملة دون اتصال بالإنترنت.

• رسالة الصباح وتأمل المساء
اختر وقتين يناسبانك، وسيذكّرك التطبيق برفق. التذكيرات تُجدوَل على جهازك وحده ولا تحتاج إنترنت.

• مجتمع للتأمل
شارك ما فهمته من حديث اليوم، واقرأ ما كتبه غيرك. كل مشاركة تُراجَع قبل ظهورها، ويمكنك الإبلاغ عن أي محتوى أو حجب أي كاتب.

• المفضلة
احفظ ما يلمس قلبك من أحاديث ورسائل، وستجده على أي جهاز تدخل منه بحسابك.

• مشاركة جميلة
حوّل أي رسالة إلى بطاقة مصمّمة تشاركها مع من تحب.

• وضع ليلي وحجم قراءة مريح
اقرأ في الليل دون إجهاد، واضبط حجم الخط كما يناسب عينيك.

• خصوصيتك محفوظة
لا إعلانات، ولا أدوات تتبّع، ولا تحليلات. لا نجمع موقعك ولا جهات اتصالك ولا صورك. يمكنك حذف حسابك وكل بياناتك من داخل التطبيق في أي وقت.

نسأل الله أن ينفع به، وأن يجعله صدقة جارية.
```

> The description above is written to be accurate, not promotional. Play
> rejects listings that promise features the app does not have, and every
> bullet here maps to something the app actually does.

---

## Graphics checklist

| Asset | Spec | Note |
| --- | --- | --- |
| App icon | 512 × 512 PNG, 32-bit **with** alpha | The opposite of Apple, which forbids alpha. Do not reuse the iOS file. |
| Feature graphic | 1024 × 500 PNG or JPEG, **no** alpha | Required. Shown at the top of your listing. |
| Phone screenshots | 2–8, min 320px, max 3840px, 16:9 or 9:16 | Four to eight converts better than two. |
| Tablet screenshots | Optional | Skip unless you want tablet visibility. |

Screenshots must show the real app. No mockups with marketing text
covering the UI.

---

## App access

The community section is behind a sign-in, so Play needs credentials:

- Provide a **demo account** (email and password) created in the
  production Firebase project.
- State in the notes that the app is **Arabic-only and right-to-left**, so
  a reviewer does not read that as a layout defect.
- State that reminders are **local notifications with no server
  component** — it heads off questions about background permissions.

Verify the demo credentials work on a fresh device immediately before
submitting.
