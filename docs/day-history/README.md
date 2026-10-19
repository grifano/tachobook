# Day history: swipe back and edit entries (MVP-07)

Task: [TachoBook — Day History: Swipe Back and Edit Entries](https://app.notion.com/p/3f9db41bd74b81d8bed7df41cd177284)
Executor: Claude Code. Branch: `claude/day-history-edit`. Base: `6dec1ffe63ef261eb1757b0066356ca36db7f7c7` (origin/main, after the Home flow merge).
Figma: [09 Home — rest, Work tab, node 490:26329](https://www.figma.com/design/rpZZnwAC53fG7zjQy42Snq/TachoBook--UI-Design?node-id=490-26329) is the past-day layout. Figma values are sample content.

## What the driver gets

- Swipe left on Home: the previous day, up to 3 days back (`DayHistory.maxDaysBack`). Swipe right: toward today. Today is the newest day; at day −3 and at today the swipe does nothing.
- A **Today** button next to the settings icon whenever a past day is shown. Hidden on today.
- A past day uses the Home layout. Work tab: frozen work card and the day summary. Rest tab: the rest taken after that shift, as HH:MM.
- An empty day shows "?" in Day started, Driving and Day closed and "--:--" in the cards. Browsing writes nothing.
- Tapping a field opens the same sheet as on Home (Shift start, Rest start, Driving time) for the selected date. Saving creates or updates that day's record. Invalid values keep Confirm disabled.
- VoiceOver: the selected day in the date strip is adjustable (swipe up/down moves a day).

## Rules as built

| Topic | Behaviour |
|---|---|
| Day | The calendar date of the shift start (device calendar). A shift across midnight stays on its start date; the next day shows empty. |
| Records | A record may hold only some fields. Past records are stored with the archived periods, so there is no schema change and existing data is untouched. |
| Active shift | Never changed by browsing or by past entries. An open (running) shift is shown only on today. A closed shift whose rest is still running is the latest closed shift: it shows on its start day and is edited with the existing Home commands. |
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

## Known differences and limits

- The Today button is not in Figma. It is a solid dark capsule (`#083F58`) next to the settings icon; translucent glass over the sky failed the contrast audit.
- Figma has no completed-rest state; the Rest card layout is reused with "Rest Taken", "Rest started", "Rest ended".
- Widget "--:--" and "?" placeholders use a heavier font weight so the audit can read them.
- Swipes are ignored while a sheet or alert is open. A horizontal swipe is also never treated as a tap on a button underneath it (found by the UI test: a swipe across the Start of day capsule opened its sheet).
- The accessibility audit passes in every past-day state at 402 pt. At 390 pt it flags the empty day (and, in some runs, other states) with "Contrast failed" on text whose measured contrast from the screenshot is about 11:1; which elements are flagged changes between runs of the same build. Home states pass at 390 pt. See the PR for the open decision.

## Run it

```sh
xcrun simctl launch --terminate-running-process booted com.grifano.TachoBook -homeFlowUITest -seedReadyWeeklyRest -resetHomeFlowTest -startDaysBack 1
```

`-startDaysBack N` (Debug only) opens day −N directly.
