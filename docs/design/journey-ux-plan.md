# رحلتي: a lighter, clearer journey tab

A small design pass, not a redesign: the same content, data and colours,
arranged so the eye knows where to go. Written 2026-11-07 from screenshots of
the tab on a Redmi (1080×2340) with a reader two hadiths in.

## What is wrong now

| | Problem | Seen as |
|---|---|---|
| 1 | Six full-width cards of equal weight, all with corner ornaments | A wall of identical boxes, about five screens of scrolling, nothing says "this first" |
| 2 | The tree card takes a whole screen, and its 40 empty leaves are pale beige on beige | Progress (٢ من ٤٢) barely shows; today's steps start below the fold |
| 3 | Today's steps: done steps still carry a chevron; the hadith row reads «أتممت حديث اليوم. التالي: «…»» and wraps | Done and next are mixed in one line; no single obvious next action |
| 4 | Streak figures are a lone large digit | «١» on its own reads like a bar, not a number of days |
| 5 | Records: 8 rows, label at one edge and value at the other | The eye crosses the whole screen for each pair; a new reader sees eight dashes |
| 6 | Pinned header (title row + section switch) is tall | About 18% of the screen before any content |

## The plan

1. **Order and weight.** The tree stays the hero, with ornaments. Every other
   card drops the corner ornaments and gets a little less padding, so the
   tab reads as one hero and a column of quieter cards. The gaps between
   cards go from 14 to 12.
2. **A smaller, clearer tree.** Capped at about 42% of the screen height.
   Empty leaves get a firmer outline so the shape reads. Under it, three
   facts in one line instead of the lone caption: read, memorized, streak.
3. **Today: one next step.** Done steps lose their chevron and go quiet. The
   first step not done gets a tinted row and a bold title. The hadith row
   becomes «حديث اليوم» with «التالي: «…»» as a smaller second line, so it
   never wraps into a paragraph. The title shows ٢ / ٣.
4. **Numbers with their units.** Streaks show «١ يوم», «٥ أيام», never a lone
   digit.
5. **Records as a grid.** Two columns of small tiles (label above, value
   below). One column under 340dp. Until the reader has any record, a single
   line says the numbers will appear after the first reading, instead of
   eight dashes.
6. **A lighter header.** Less space above and below the title, and a
   slightly shorter section switch.

## Not changing

Colours, fonts, the tree's layout, the four tabs, any wording rules, and
every behaviour. The static and end-to-end suites must pass unchanged
afterwards, and the UI suite's text checks are updated only where a line
was split on purpose.
