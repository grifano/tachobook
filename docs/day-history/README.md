# Day history: swipe back and edit entries (MVP-07)

Task: [TachoBook — Day History: Swipe Back and Edit Entries](https://app.notion.com/p/3f9db41bd74b81d8bed7df41cd177284)
Executor: Claude Code. Branch: `claude/day-history-edit`. Base: `6dec1ffe63ef261eb1757b0066356ca36db7f7c7` (origin/main, after the Home flow merge).
Figma: [09 Home — rest, Work tab, node 490:26329](https://www.figma.com/design/rpZZnwAC53fG7zjQy42Snq/TachoBook--UI-Design?node-id=490-26329) is the past-day layout. Figma values are sample content.

## What the driver gets

- Swipe right on Home (finger moves right, as in iOS Calendar): the previous day, up to 3 days back (`DayHistory.maxDaysBack`). Swipe left: toward today. A swipe further back on the oldest day shows a small label "Older days are in History." near the strip (it leaves after 3 s or on any tap, and returns with the next such swipe; no navigation). Today is the newest day; at day −3 and at today the swipe does nothing.
- The date strip is fixed: `DayHistory.maxDaysBack` days before today, today, and the days after today that fill the five slots (3 back, today, tomorrow). Swiping or tapping moves only the selection circle; the dates never scroll, and the strip updates at midnight. Figma centres the selected day; this is an approved difference.
- Dates in the header strip that the swipe can reach (today and 3 days back) are buttons and open that day. Other dates (deeper, or in the future) do nothing and look the same. Tap targets are 44 pt; VoiceOver reads the full date.
- A **Today** button next to the settings icon whenever a past day is shown. Hidden on today.
- A past day uses the Home layout. Work tab: frozen work card and the day summary. Rest tab: the rest taken after that shift, as HH:MM.
- An empty day shows "?" in Day started, Driving and Day closed and in the cards. Browsing writes nothing.
- A past day with no shift that one rest covers whole (it started on an earlier day and ended on a later day or is still running) shows one line in the summary card: "No shift this day — you were resting since Sat 17, 23:52." A tap opens the day the rest started if the swipe can reach it; otherwise it is plain text. Interim copy; the Figma design for this state is a separate task.
- Tapping a field opens the same sheet as on Home (Shift start, Rest start, Driving time) for the selected date. Saving creates or updates that day's record. Invalid values keep Confirm disabled, and every time sheet (Home and past days) says why in one line under the picker.
- VoiceOver: the selected day in the date strip is adjustable (swipe up/down moves a day).

## Rules as built

| Topic | Behaviour |
|---|---|
| Day | The calendar date of the shift start (device calendar). A shift across midnight stays on its start date; the next day shows empty. |
| Records | A record may hold only some fields. Past records are stored with the archived periods, so there is no schema change and existing data is untouched. |
| Active shift | Never changed by browsing or by past entries. An open (running) shift is shown only on today. A closed shift whose rest is still running is the latest closed shift: it shows on its start day and is edited with the existing Home commands. |
| Animations | Standard SwiftUI animations (`withAnimation`, system transitions): Work/Rest switch (native segmented `Picker`), day change (push; cross-fade with Reduce Motion), the selection circle (`matchedGeometryEffect`; fades in place with Reduce Motion), Today button, the rest note, the history hint and the reason line. Sheets keep the system presentation. |
| Reasons under a disabled Confirm | Future: "This time hasn't happened yet." Day closed before Day started: "Day closed can’t be before Day started (Fri 16, 06:10)." Overlap: "This overlaps your shift from Wed 14, 20:10 to Sun 18, 20:01." (open shift: "…your current shift from Wed 14, 20:10.") Time outside the day: "Pick a time on Sat 17." Dates and times follow the device locale. The validators return the reason (`TimeEntryIssue`); a disabled case without approved copy (Start of day before the rest milestone, a rest-link edge) shows nothing. |
| Validation (R-E01) | Start on the selected day and not in the future. End not before start, not in the future. No overlap with another record or the running shift (touching at one instant is allowed). Driving not negative. Start of day on Home cannot precede the end of an entered past shift. |
| Rest taken | Next shift start minus this shift end. If there is no later shift: time up to now, labelled "So far", end "Running". No Day closed: placeholder. Not classified as daily or weekly; no 9/11/24/45 h markers. |
| Default time in sheets | The current time of day on the selected date (an existing value when editing). |
| Recompute | Rest taken, durations and limits are derived on every render from the stored timestamps, so editing a day updates its neighbours. |

## Screenshots (Debug, simulator)

Day −1 of the seeded scenario (`-homeFlowUITest -seedReadyWeeklyRest`, yesterday is always empty). The filled day was entered through the UI with the default time of day, so start and close are the same minute. Figma references: [frame 09](../home-flow/figma-09.jpg), [driving sheet](../home-flow/figma-07.jpg), [rest start sheet](../home-flow/figma-05.jpg). Figma has no Today button and no completed-rest state.

| State | Figma | 402 pt | 390 pt |
|---|---|---|---|
| Empty day, Work tab | ![](../home-flow/figma-09.jpg) | ![](empty-402.jpg) | ![](empty-390.jpg) |
| Filled day, Work tab | ![](../home-flow/figma-09.jpg) | ![](filled-402.jpg) | ![](filled-390.jpg) |
| Rest tab (rest taken) | ![](../home-flow/figma-09.jpg) | ![](rest-402.jpg) | ![](rest-390.jpg) |
| Edit sheet (Driving, prefilled) | ![](../home-flow/figma-07.jpg) | ![](edit-driving-402.jpg) | ![](edit-driving-390.jpg) |
| Day −3, the limit | — | ![](limit-402.jpg) | ![](limit-390.jpg) |
| Date strip with the selected day (Sat 17) | — | ![](strip-402.jpg) | ![](strip-390.jpg) |
| Note on a day covered by rest | — | ![](note-402.jpg) | ![](note-390.jpg) |
| Tab bar (Figma shows the orange pill, overridden) | ![](tabbar-figma.jpg) | ![](tabbar-402.jpg) | ![](tabbar-390.jpg) |
| Today, Light mode | — | ![](today-light-402.jpg) | ![](today-light-390.jpg) |
| Today, Dark mode | — | ![](today-dark-402.jpg) | ![](today-dark-390.jpg) |
| Past day, Light mode | — | ![](past-light-402.jpg) | ![](past-light-390.jpg) |
| Past day, Dark mode | — | ![](past-dark-402.jpg) | ![](past-dark-390.jpg) |
| Hint at the history limit | — | ![](hint-402.jpg) | ![](hint-390.jpg) |
| Reason under the picker (stored shift covers yesterday) | — | ![](reason-402.jpg) | ![](reason-390.jpg) |

## Tab bar (F7: native bar, option A, updated 2026-10-20)

The custom bar is replaced by the standard Apple `TabView` (`ContentView`): Home, History, Violations, Restrictions as in Figma node 490:26372. SF Symbols (as in Figma): `house`, `calendar.badge.clock`, `exclamationmark.circle.fill`, `globe.badge.clock.fill`. History, Violations and Restrictions are `.disabled(true)`: dimmed, a tap does nothing, no screens. Icons and labels are white in Light and Dark mode, the selected Home tab included (`.toolbarColorScheme(.dark, for: .tabBar)` and `.tint(white)`); the selection is the system's own highlight, not orange. Figma reference: [here](tabbar-figma.jpg) (it shows the orange pill, which Serhii overrode); app: [402 pt](tabbar-402.jpg), [390 pt](tabbar-390.jpg).

Accepted audit exclusion (temporary): SwiftUI gives the dimmed tabs no "not enabled" trait, so VoiceOver does not say "dimmed" and the audit reports "Missing trait: UIAccessibilityTraitNotEnabled" for them. `TachoBookUITests/AccessibilityAuditSupport.swift` ignores exactly that issue for the three tab buttons (audit type `.trait`, description contains `UIAccessibilityTraitNotEnabled`, element a button labelled History, Violations or Restrictions). Every other issue still fails. Remove it when those tabs become active.

Open and accepted by Serhii: with the native bar the audit flags one or two texts on the past empty day on some runs at 402 pt (measured contrast about 11:1; clean 3 of 3 with the old bar). That one audit step is a non-strict expected failure; the filled day and Rest tab audits are strict.

## Text colours (F9, 2026-10-20)

Text has two named colours, identical in Light and Dark mode, defined once in `TachoTheme` (`Color.tachoTextOnLight`, `Color.tachoTextOnDark`), from the Figma variables read with `get_variable_defs`:

| Colour | Figma variable | Value | Where |
|---|---|---|---|
| `tachoTextOnLight` | `Labels/Primary` | #072B3C | cards, Work/Rest switch, Day summary, sheets, light chips (Start at / dimmed Start of day) |
| `tachoTextOnDark` | `Grays/White` | #FFFFFF | header day and date, date strip, Today button, history hint, tab bar, filled buttons (Start of day, End of day, sheet confirm) |

Orange (#E8652A, `orangeStrong`) stays on fills only: icon badges, gauge arc, filled buttons, sheet grabber and confirm. No text is orange. Places where Figma or the earlier build used another text colour, now following the rule:

| Place | Was | Now |
|---|---|---|
| Rest card title and subtitle ("Weekly Rest", "Closed 18 Oct …"), card titles ("Day summary", "Last Shift Summary", "Next rest …") | blue #116B93 / #083F58 | navy |
| Red remaining time under the gauge (00:15) | red #A3322B | navy (the exclamation icon stays) |
| "Start at / End at" chip text on the green chip | green #1F4A31 | navy |
| Dimmed "Start of day" label | gray #4F4F4F | navy |
| Sheet subtitle and the reason line | gray #727272 | navy |
| Date strip, neighbouring dates (Figma 50 % / 25 % white) | solid 93 % / 86 % white | white (strip text is one colour; the circle marks the selection; unreachable dates no longer look dimmer) |
| Work/Rest switch labels | system label colour (white in Dark mode on a light card) | navy in both modes (the switch is forced to the light scheme; `UISegmentedControl` title colour set in `TachoBookApp`) |
| Today button and history hint fill | #083F58 | #072B3C (fill, text white) |

No surface needed a third colour for AA: navy on the light card fill reaches 4.5:1 (unit test), white on the darkened photo header and on the navy/orange fills was already measured by the audit. Light and Dark screenshots: today [402](today-light-402.jpg) / [dark](today-dark-402.jpg), past day [402](past-light-402.jpg) / [dark](past-dark-402.jpg); 390 pt files have the same names with `-390`.

## Known differences and limits

- The Today button is not in Figma. It is a solid dark capsule (`#083F58`) next to the settings icon; translucent glass over the sky failed the contrast audit.
- Figma has no completed-rest state; the Rest card layout is reused with "Rest Taken", "Rest started", "Rest ended".
- Widget "--:--" and "?" placeholders use a heavier font weight so the audit can read them.
- Swipes are ignored while a sheet or alert is open. A horizontal swipe is also never treated as a tap on a button underneath it (found by the UI test: a swipe across the Start of day capsule opened its sheet).
- The accessibility audit passes in every past-day state at 402 pt (the note text needed a medium font weight). At 390 pt it flags the empty day (and, in some runs, other states) with "Contrast failed" on text whose measured contrast from the screenshot is about 11:1; which elements are flagged changes between runs of the same build. Home states pass at 390 pt. Serhii accepted this as a tool flake on 2026-10-19.

## Run it

```sh
xcrun simctl launch --terminate-running-process booted com.grifano.TachoBook -homeFlowUITest -seedReadyWeeklyRest -resetHomeFlowTest -startDaysBack 1
```

`-startDaysBack N` (Debug only) opens day −N directly. `-seedLongShift` (Debug, with `-homeFlowUITest`) stores a shift from three days ago 20:10 to just after midnight today; yesterday's default start then overlaps it and the sheet shows the reason.
