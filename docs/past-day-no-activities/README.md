# Past day: No activities widget (Home)

Screenshots from iPhone 17e (390 pt wide, iOS 27.2 simulator), Debug build of branch `claude/past-day-no-activities`,
taken by `DayHistoryUITests` (full run on 22.11.2026). Seeds: `-seedReadyWeeklyRest` (one shift 49 h ago, then a weekly
rest that still runs), `-seedNearDutyLimit` (only the open shift), `-seedOldShift` (one shift six days ago),
`-seedLongShift` (a shift from three days ago that crossed midnight). The shifts have no country unless the test picked one.
Reference: Figma "Past Day Covered - 02 - No activities, Add and Home button" (838:33650).

| File | What it shows |
| --- | --- |
| `1-no-activities-last-activity-390.jpg` | Yesterday without a shift: the widget with the last activity, "Add" and the round Home button in the header |
| `2-no-activities-no-earlier-shift-390.jpg` | No earlier shift at all: only the top part of the widget |
| `3-tap-to-see-this-day-home-button-390.jpg` | After "Tap to see this day" (within 3 days): the day of the last shift; the Home button replaces "Today" |
| `4-older-day-in-history-390.jpg` | Last shift older than 3 days: "Tap to see this day" opens History with that day's summary |
| `5-add-shift-start-sheet-390.jpg` | "Add" on Home: the same Shift start sheet as on History, for the viewed day |
| `6-after-saving-390.jpg` | After start → close → driving: the widget is gone, the normal past day shows the new shift |
| `7-covered-day-replace-alert-390.jpg` | Add on a day a stored shift overlaps: the flow asks before replacing it |

The sample values (a zero-length shift at the current time, Poland) come from the UI tests, which keep the default
times. 402 pt screenshots were not taken: the project runs everything on one simulator (iPhone 17e, 390 pt).
