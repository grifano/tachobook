# Live shift duration timer

Task: https://app.notion.com/p/3f7db41bd74b819fb55bea4d8d7788d8
Executor: Codex. Base: `1088dd11d647bcc377cc9ef159176c49fcbd6de5`.
Branch: `codex/live-shift-duration-timer`.
Figma timer: https://www.figma.com/design/rpZZnwAC53fG7zjQy42Snq/TachoBook--UI-Design?node-id=354-20592

Serhii approved the additional minimal persistence and Close/Resume scope in chat on 2026-10-14. The regulatory engine remains a separate task.

Active duration is `now - original duty start`, including intermediate rests. Close saves the end event and starts uninterrupted rest immediately, without requiring driving duration first. Resume ends and retains that rest segment, keeps the duty ID/start and entered driving total, and returns to elapsed duty duration. A new period archives the previous record and starts at the actual action timestamp.

The app stores one versioned JSON journal in Application Support with atomic writes, absolute Foundation Date values, stable record IDs and the original timezone identifier. Production, unit-test temporary files and UI-test journals are separate. Read/write failures are visible and prevent overwriting an unreadable journal. Existing in-memory sample data has no persisted records to migrate.

## Qualification boundary

The 9/11-hour clock milestones and the 15-hour visual gauge scale do not evaluate legal availability. Resume records actual continuation; it does not grant permission. New shift requires explicit manual confirmation that the uninterrupted rest satisfies the driver's daily-rest requirement, and records that confirmation. It is never created automatically at a milestone. Reduction counts, split qualification, weekly rules and exceptions are not implemented. The summary says “Not evaluated”. Original-start edits and timeline deletions are disabled after rest begins to preserve recorded segments; driving totals remain editable.

## Verification

Verified on 2026-10-14 with Xcode 26.6 (17F113), iOS 26.5 Simulator:

- Final full build/test command: **passed**, 21 tests / 23 executions including parameterized runs, 0 failures. Result: `/private/tmp/tachobook-codex-live-review.xcresult`.
- iPhone 12 mini timer UI checks: **3 passed**, 0 failures. Result: `/private/tmp/tachobook-codex-live-narrow.xcresult`.
- `git diff --check`: passed.

Screenshots: [active](active.png), [rest](rest.png), [new shift](new-shift.png), [narrow screen with large text](narrow-large-text.png).

Full build + unit/UI suite:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project TachoBook.xcodeproj -scheme TachoBook \
  -destination 'platform=iOS Simulator,id=3E3841BC-7DE2-4239-A650-75D36B32CA96' \
  -derivedDataPath /private/tmp/tachobook-codex-live-build \
  -resultBundlePath /private/tmp/tachobook-codex-live-review.xcresult \
  -parallel-testing-enabled NO
```

Narrow-screen UI checks (iPhone 12 mini, iOS 26.5):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project TachoBook.xcodeproj -scheme TachoBook \
  -destination 'platform=iOS Simulator,id=BBBE008F-8608-4AAD-B349-899D529DD70B' \
  -derivedDataPath /private/tmp/tachobook-codex-live-build \
  -resultBundlePath /private/tmp/tachobook-codex-live-narrow.xcresult \
  -only-testing:TachoBookUITests/LiveShiftTimerUITests -parallel-testing-enabled NO
```

Use a new result-bundle path for subsequent runs. Xcode's normal simulator signing is enabled. Earlier unsigned-runner attempts encountered `Busy / Application failed preflight checks`; the signed full regression passed on an isolated simulator. The global developer directory was left unchanged.

| Requirement | Evidence |
| --- | --- |
| Live seconds, foreground and app restart | `testLiveTimerForegroundRestartCloseAndResume` |
| Midnight/long intervals and second/minute formatting | `elapsedUsesOriginalInstantAcrossMidnightAndLongIntervals` |
| Spring/autumn DST absolute-duration arithmetic | `dstDoesNotChangeElapsed` (two inputs) |
| Close, Resume, multiple rests and driving retention | `closeResumeAndSecondCloseKeepDutyAndAllEntries` |
| Actual persistent record restoration and archived new shift | `restartRestoresActiveAndRestingStateAndArchivesNewShift` |
| No automatic reset; closing without driving total | `closingWithoutDrivingImmediatelyStartsRestAndMilestonesDoNotResetPeriod` |
| Invalid transitions and unreadable-journal preservation | `invalidTransitionsAndUnreadableStorageDoNotDestroyData` |
| Explicit New shift confirmation | `testNewShiftRequiresConfirmationAndStartsAtActualStart` |
| Large text and 375/390 pt layouts | `testTimerFitsNarrowScreenWithLargeText`, existing dashboard layout tests |

Screenshots were compared with Figma node 354:20592: native 28 pt bold main value, 8 pt bold seconds below, no seconds suffix, Dynamic Type scaling, and the existing adaptive gauge. The label “Shift elapsed” identifies the actual metric. Regulatory warning colors/icons are not inferred from elapsed duration. Existing tab-bar wrapping at large text is outside this timer task.

## Human review

1. Start a shift, observe the seconds, background/relaunch and verify the original start is retained.
2. Close, check the frozen shift value, rest clock and +9/+11 instants. Resume and verify the original start and driving total remain; view retained rest segments in Day summary.
3. For a fast new-period review, use Debug launch arguments `-timerUITest -resetTimerTest -longRestUITest`. This uses a separate test journal. Confirm the daily-rest decision explicitly; verify the new timer begins at zero. Remove the test arguments for normal use.

Physical iPhone/TestFlight execution and regulatory eligibility checks were not performed.
