# Add past shift (History)

Screenshots from iPhone 17e (390 pt wide, iOS 27.2 simulator), Debug build of branch `claude/add-past-shift`, taken by
`HistoryUITests` with the `-seedHistoryWeek` sample records. The `-402` files are the same test on iPhone 17 (402 pt
wide, iOS 27.2), run only for these screenshots with Serhii's approval (17.11.2026).
Reference: Figma "Design v2" → "Flow - Add Past Shift" / "Add Past Shift - 01 - Calendar with add button" (814:11488);
the sheets are the existing "Sheet / Time Entry" and Driving time sheets.

| File | What it shows |
| --- | --- |
| `1-history-add.jpg` | History tab: the glass "Add" button (calendar.badge.plus) in the header's trailing slot |
| `2-shift-start.jpg` | Add → the normal Shift start sheet; the seeded shifts have no country, so the driver picks one |
| `3-close.jpg` | The normal close sheet ("Rest start"), country prefilled from the start |
| `4-replace-alert.jpg` | A second entry on a day that already has a shift asks whether to replace it |
| `5-day-summary-editable-390.jpg` | Iteration 2: the History Day summary of a past day; Day started, Driving and Day closed are buttons |
| `6-edit-sheet-390.jpg` | Iteration 2: Day closed opens Home's earlier-day edit sheet over the summary |
| `7-after-save-390.jpg` | Iteration 2: after 20:00 → 19:00 the rest is 11 h: the rings update and the bed on that day is gone |
| `5-day-summary-editable-402.jpg`, `6-edit-sheet-402.jpg`, `7-after-save-402.jpg` | The same three at 402 pt (iPhone 17) |

The sample values in the alert (a zero-length shift at the current time) come from the UI test, which keeps the
default times.
