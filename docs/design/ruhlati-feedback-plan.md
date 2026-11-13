# رحلتي — plan from the testers' feedback

Date: 2026-11-13. Scope: only the changes asked for after the testers' feedback.
Each phase is its own branch, worktree and PR. A phase is merged before the next one starts.

## Phase 0: Check what is already on main (done)

PR #19 (`e43e3a0`) already shipped part of the list. Checked on the emulator with a reader who is ten days in:

| Ask | State | Evidence |
|---|---|---|
| Tree 1: each leaf shows its hadith number | **Done.** Arabic numerals on all 42 leaves. | emulator screenshot |
| Tree 2: three looks only | **Done.** Not read is cream with a gold edge, read is green, memorized is gold (`LeafLook.empty / complete / memorized`). The extra "next" and "started" looks are gone. | `journey_tree.dart:20`, screenshot |
| Tree 3: numbers in order | **Not done.** The numbers zigzag: 13 is at the top left, 14 is low by the trunk, then it jumps back up. 25 and 38 are low as well. | numbering path drawn over the tree |
| «راجع حفظك» button and page | **Partly done.** The button and page exist. Today's reviews are at the top, and a reviewed card turns green and says when it comes back. It needs the design work in Phase 3. | screenshots |

## Phase 1: Tree order and leaf key

**Change**
- Renumber the 42 places in `TreeLayout._places` (`journey_tree.dart:78`) so that each number sits next to the one before it. Only the places are reordered. A hadith's number never changes, so no saved data is affected.
- Direction (recommended): right to left, like Arabic reading. Start at the lower right, go up over the top and finish at the lower left. All the leaves on one branch stay consecutive. Say so if you would rather have left to right.
- Rename the leaf key: «مكتمل» → «قرأته». Also update the screen reader text in `_describe`.

**Tests**
- Unit (`test/features/journey_tree_test.dart`): leaf *n* and leaf *n+1* are no further apart than a set distance, for all 41 pairs. Leaf 1 is on the right half and leaf 42 is on the left half.
- Emulator: the screenshot run, plus the numbering path drawn over the tree. It should be one line that never crosses back.

## Phase 2: «خطوات اليوم» page and the home ring

**Change**
- New `TodayStepsScreen` page with the three steps as large, clear rows: اقرأ رسالة اليوم، اقرأ حديث «…»، اكتب ما بقي معك من الحديث. Each row opens its own screen. A done step shows a tick and the row goes quiet. A short line at the top: «خطوة واحدة تكفي ليُحسب يومك».
  - Note: writing alone does not count a day in the streak rule (`JourneyDay.isPresent`). The line must say what is true, or the rule must change. Recommended: keep the rule and word the line as «اقرأ الرسالة أو الحديث ليُحسب يومك».
- On رحلتي, the inline «خطوات اليوم» card becomes one button: «خطوات اليوم ٢ / ٣ ›», which opens the page.
- Home ring, top left (`journey_ring.dart`):
  - The centre shows the steps done today (٠ to ٣) instead of the streak.
  - New colours: an empty track; each done arc in gold; the whole ring turns green with a tick when all three are done.
  - Tapping the ring opens `TodayStepsScreen` instead of the رحلتي tab.

**Tests**
- Unit: `DaySteps.done` for each combination of the three steps.
- Widget: the ring shows ٢ after a message and a hadith, and turns green at ٣.
- Emulator, integration (`ui_suite_test.dart`): tapping the ring opens the steps page. Each row opens its screen. The رحلتي button shows the same count as the ring.

## Phase 3: «راجع حفظك» page design

**Change** (`memo_list_screen.dart`, `MemoEntry`)
- **Entry on رحلتي:** one well-designed button next to «خطوات اليوم». It has a gold leaf icon and a small badge with the number due today. The second line is short: «موعد مراجعة حديثين اليوم» or «كلها ثابتة».
- **The page is one list.** It does not have three separate blocks.
  1. **Due today**: one or two cards with a gold border and the tag «دوره اليوم». Each has one small «راجِع» button, not a full-width green block. If more than two are due, the first two are shown and a «و٣ غيرها» line opens the rest.
  2. A clear separator: «كل ما تحفظه (٥)».
  3. Every other memorized hadith, as quiet rows: leaf number, title, strength dots, and when its next review is.
  4. Hadiths still being learned sit in this list with «أكمل».
- **No repeats.** Today the three due hadiths show twice, once as cards and again in the list below. In the new list a hadith appears once.
- **After a review:** the card plays a short change (the border goes from gold to green, a tick, one more strength dot) and says when the hadith comes back. It stays at the top until the reader leaves the page, then joins the list.
- **Gentler copy:** «تأخر ٩ أيام» → «فاتك موعده، ودقيقة تكفي». It follows the voice rules in `journey_copy.dart`.

**Tests**
- Unit (`test/features/memo_plan_test.dart`): due hadiths come first and no hadith appears twice. Learning hadiths are in the list.
- Emulator: seed three due hadiths, review one, and check that its card changes and the count drops. The screenshots before and after go in the PR.

## Phase 4: The numbers (حصاد الأسبوع / حصاد رحلتك) and how they are counted

**Change**
- One numbers card replaces «أنت مقابل نفسك», the points row and the 8-tile «أرقامك» card. It has two parts:

| حصاد الأسبوع | حصاد رحلتك |
|---|---|
| الاستمرارية: days in a row now | أفضل استمرارية: all time |
| أفضل استمرارية هذا الأسبوع | نقاطك كلها |
| نقاط الأسبوع | حفظت ٣ / ٤٢ |

- The word «سلسلة» becomes «استمرارية» everywhere: the tree line, the ring's screen reader text, the completion sheet and the posters.
- Removed from the tab: the grace-day figure, the minutes bars and the 8 records. A broken record is still celebrated on the screen after a reading.
- **«كيف تُحسب؟»:** a small ⓘ on the card opens a short, calm sheet with three short sections:
  - الاستمرارية: a day counts when you read the message or a hadith, or review your memorization. You get one free day for every 7 days in a row.
  - النقاط: a small table: رسالة ٢، حديث ١٠، حفظ ١٥، مراجعة ٣، مشاركة ٢، رسالة مقبولة ١٥, with the daily limits in one line.
  - المحفوظ: how many of the 42 you hold by heart.
- **Data:**
  - New `bestStreakInWeek(days, weekStart)` and `totalPoints(data, approvedOn)` in `journey_points.dart` / `journey_engine.dart`.
  - Only the current and last year of days are loaded, so the all-time total covers those two years. That is enough now, because the app started in 2026. Storing a running total can wait until it matters.

**Tests**
- Unit: the best streak inside a week, with gaps and a grace day; the total points across a week boundary and with the weekly cap.
- Widget: the card shows six numbers, and ⓘ opens the sheet.
- Emulator: update the old expectations in `ui_suite_test.dart` («سلسلتك الآن», «أيام سماح», «أرقامك») to the new card.

## Phase 5: Sharing «حصاد الأسبوع»

**Change**
- Redesign `HarvestPoster` (`journey_posters.dart`) around the three weekly numbers: الاستمرارية، أفضل استمرارية، نقاط الأسبوع.
  - Three large tiles with a gold leaf above each, the week's dates, and the app name.
  - Both formats: منشور 360×450 and حالة 360×640.
- The share button sits under the حصاد الأسبوع part of the numbers card.

**Tests**
- Widget: the poster shows the three numbers in both formats, and in dark mode.
- Emulator: open the share sheet and screenshot both formats for review.

## Phase 6: «لوحة الأسبوع» design and nicknames

**Change** (`weekly_board_screen.dart`, `board_service.dart`, `weekly_board.dart`)
- **Design**
  - Header: the week and «تُنشر كل جمعة».
  - The three lists are custom pill tabs, not the default Material `SegmentedButton`.
  - The top three get a gold, silver or bronze leaf. The other rows have a rank circle, the name and the value.
  - Your own points and the join switch merge into one card at the bottom.
- **Nickname instead of «فاعل خير»:**
  - Joining the board asks for a nickname: 2–20 letters, digits and spaces, with a short list of blocked words. The name can be changed later from the same card.
  - Readers already on the board as «فاعل خير» are asked for a nickname the next time they open the board.
  - Storage: the nickname goes into `scores/{uid}.name`. The rules already allow any name of up to 40 characters, so **no rules deploy is needed**.
  - Nicknames do not have to be unique, and moderators can still remove an entry from the dashboard.

**Tests**
- Unit: the nickname rules (too short, too long, symbols, a blocked word, spaces trimmed).
- Emulator: join with a nickname and check it shows in the card; change it; leave the board.
- Dashboard: run the existing `weekly_board_page_test.dart` to check the moderator page still reads names.

## Test routine after every phase

1. `flutter analyze`, then `flutter test` (unit and widget) on the PC.
2. **Emulator** (Pixel_10_Pro, started with `-dns-server`):
   - Run `integration_test/ui_suite_test.dart` with its expectations updated for the phase.
   - Run a seeded screenshot pass of the changed screens, light and dark.
   - The screenshots go into the PR.
3. **Redmi phone:**
   - `flutter test` is never run on it, because it can reinstall the app and wipe its data.
   - Instead, build the release APK and install it with `adb install -r`, which keeps the data.
   - Then do a short checklist for the phase on real data. I take adb screenshots, and you tap through anything that needs a real account.
4. Restore `GeneratedPluginRegistrant.java` after any `flutter test` or `pub get`.

## Decisions to confirm

- **Tree direction:** right to left (recommended) or left to right.
- **Streak rule:** keep it as it is (writing alone does not count a day), and word the steps page to match. This is recommended.
- **Arabic copy:** a native speaker should read the new copy before Phase 4 ships.
