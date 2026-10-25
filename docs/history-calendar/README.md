# History: month calendar and Day summary sheet

Task: [TachoBook — History: Month Calendar + Day Summary Sheet](https://app.notion.com/p/403db41bd74b81dd8ef4e4a4087dcbab).
Figma: frame 01 `708:31832` (calendar), frame 02 `708:31844` (Day summary sheet, medium detent), legend `707:30740`.
Frame 03 `708:31874` (violations) is out of scope.

## Behaviour

- History tab is active (Violations and Restrictions stay inert). Home and History share one `DayLogModel`.
- Native `UICalendarView` (`HistoryCalendar`, `UIViewRepresentable`): current month, month arrows, future dates
  outside `availableDateRange` (dimmed, not selectable). Per Serhii (25.10.2026) the dates are smaller and the card
  edges have more room: the calendar gets a text size two steps below the reader's own
  (`traitOverrides.preferredContentSizeCategory`, so it still follows Dynamic Type) and a 12 pt side inset.
  Scaling the view instead was tried and dropped: a UIKit transform showed the wrong month page, and a SwiftUI
  `scaleEffect` left the full-size view over the legend, which made the contrast audit fail.
  A tap opens the sheet; the selection is cleared at once, so the same date can be tapped again.
- Markers (`HistoryMarkers.swift`), derived from stored records on every read:
  - **Bed** (`bed.double.fill`): on the day of the shift whose following rest is reduced (Serhii, 25.10.2026),
    not the day that rest ended; a shift past 13 h shows it while its rest still runs. A rest of 24 h or more
    after the shift is weekly, so no bed. Unknown count (no completed weekly rest) → no bed.
  - **Wheel** (`steeringwheel`): the day's shift has driving over 9 h and up to 10 h. Over 10 h is a violation
    (later task) and gets no marker yet.
  - A shift across midnight belongs to its start date (`DayHistory.recordDay`).
  - VoiceOver: the date cell reads "Friday, October 23" with the value "reduced rest, extended driving".
- Legend (interim copy, decision 6): hint "Tap a date to see that day.", bed + "Reduced rest (9–11 h)",
  wheel + "Extended driving (10 h)". No "Rule broken this day" line.
- Day summary sheet (`DaySummarySheet.swift`), read-only, medium and large detents: title "Day summary",
  subtitle "23 Oct 2026", Work gauge (duration vs 15 h, hammers), Rest gauge (rest taken, beds), Day started /
  Driving / Day closed. Times and gauges come from the same helpers as Home's past-day cards. The bed/hammer
  row counts every reduction up to that day including the rest after that day's own shift
  (`historyReducedRests(onDay:)`), so on 21.10 it already shows 1. Home's past-day row still shows the count
  at the end of the day (PR #13 rule), so it can be one lower than the sheet. A day without a record shows
  "No records for this day."

## Screenshots (iPhone 17 Pro, 402 pt)

| Figma 01 | App | Figma 02 | App, data | App, empty day |
|---|---|---|---|---|
| ![](figma-708-31832.png) | ![](calendar-402.jpg) | ![](figma-708-31844.png) | ![](sheet-data-402.jpg) | ![](sheet-empty-402.jpg) |

390 pt: `calendar-390.jpg`, `sheet-data-390.jpg`. Home, earlier day 22.10 (402 pt): `home-past-work-402.jpg`
("13h"), `home-past-rest-402.jpg` ("9h").

## Known gaps against Figma

- Legend lines use Caption (12 pt) instead of Figma's Caption 2 (11 pt): with Caption 2 the accessibility audit
  reported "Dynamic Type partially unsupported" for them in about one run in three.
- Past-day gauge labels (Serhii, 25.10.2026), on Home's earlier days and in the sheet: Work "13h" up to 13 h of
  duty, "15h" beyond; Rest "9h" under 11 h, "11h" up to 24 h, "24h" up to 45 h, "45h" from 45 h, "So far" while
  running. Figma shows "15h" / "9h" as sample values. The arc fill keeps its scale (15 h for Work, 9 h for Rest).
- Day numbers are two text sizes smaller than the system default (about 18 pt instead of Figma's 20 pt), at
  Serhii's request.
- Native calendar look: rows are taller (UIKit reserves space for decorations), weekday headers are system
  gray, day numbers are system black, and the week starts on the device's first weekday.
- Today is navy (tint), not orange: F9 allows only navy text on light surfaces.
- At the largest text sizes the system calendar grows its day numbers only part of the way; the UI-test audit
  ignores exactly that issue for day-number labels (`isNativeCalendarDayNumber`).
- iOS 26 draws the medium-detent sheet slightly scaled down; the sheet audit runs on the expanded sheet.
