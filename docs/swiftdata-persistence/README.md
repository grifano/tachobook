# SwiftData persistence verification

Task: https://app.notion.com/p/3f9db41bd74b81c8a850fccf7cb2a43d
Executor: Codex. Branch: `codex/swiftdata-persistence`.
Base: `4411c35e2414cb1b2c6e8d53270a89d6a15b14f1` (current main at branch creation).
Worktree: `/Users/sorlenko/iOSDev/TachoBook/codex/persistence`.
Verification date: 2026-10-14. Xcode 26.6 (17F113), iOS 26.5 Simulator, iPhone 17e.

## Inspection and reuse

Read-only inspection used `git status --short`, `git diff`, `git branch -avv`, `git worktree list`, `git log`, `git reflog --all -12`, and `git ls-remote origin` in the two existing checkouts, plus live Notion tasks and GitHub PR metadata.

The previous Codex implementation is commit `5f239c018ab14b922cc9befad92bed8d1a828c71`, which contains the JSON journal, DutyPeriod/RestSegment value types, Close/Resume commands, and timer UI. Remote inspection found it already merged via PR #3 into main at `4411c35`; PR #2 was closed without merge. `git diff 5f239c0 origin/main --stat` returned no changes. The earlier task integration-order text was stale. This PR reuses that implementation directly from main and replaces its storage mechanism. No competing implementation or commit movement was needed.

Original Codex checkout remained on its timer branch at `5f239c0`, including its existing untracked Xcode workspace user state. Claude checkout was clean and preserved. Timer branches/PRs were not modified.

Branch preparation:

```sh
cd /Users/sorlenko/iOSDev/TachoBook/codex/tachobook
git fetch origin
git rev-parse origin/main
# 4411c35e2414cb1b2c6e8d53270a89d6a15b14f1
git worktree add -b codex/swiftdata-persistence /Users/sorlenko/iOSDev/TachoBook/codex/persistence origin/main
```

## Storage contract

- Versioned SwiftData schema v1, local SQLite store at Application Support `TachoBook/shifts-v1.store`; CloudKit explicitly disabled.
- One record per duty ID, one current record, ordered archived periods. Absolute Date values, original calendar timezone, entered driving minutes, closed state, and ordered rest segments are retained. Rest segment value data is explicitly encoded; it is not queried independently.
- Existing model commands and approved Close/Resume/New shift behavior are unchanged. Commands save explicitly in one context transaction; a failed save rolls back and does not publish the proposed state. No timer tick writes to disk.
- Existing `shift-journal-v1.json` imports only when the native store has no records. The original file remains untouched as a recovery copy. SwiftData becomes authoritative; later JSON changes are ignored. Saving an empty current record prevents reset/deletion from reimporting old data.
- Open/decode/save errors remain visible through the existing error UI and lock mutations. The app does not delete a failed store or switch to an operational in-memory fallback.
- Tests/previews may explicitly use memory. Debug UI checks use separate store paths. `-persistenceUITest` never seeds records; `-resetPersistenceTest` only deletes its dedicated test directory.
- No history navigation, regulatory engine, schema from an older SwiftData implementation, backend, deployment-target change, or third-party dependency was introduced. No local SwiftData app implementation was found in the inspected checkouts/refs/reflog; historical memory was not treated as current-code evidence.

## Automated verification

Run from `/Users/sorlenko/iOSDev/TachoBook/codex/persistence`.

Initial unit run, exit 0, 20 Swift Testing tests passed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=B63DB03E-4B05-4239-A201-6CCA7681B887' -derivedDataPath /private/tmp/tachobook-swiftdata-build -resultBundlePath /private/tmp/tachobook-swiftdata-first.xcresult -only-testing:TachoBookTests -parallel-testing-enabled NO > /private/tmp/tachobook-swiftdata-first.log 2>&1
```

Full build/unit/UI run, exit 0, **29 tests / 32 executions, 0 failures, 0 skipped**. Three parameterized tests account for the additional executions. Ten UI executions passed, including real process termination/relaunch:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=B63DB03E-4B05-4239-A201-6CCA7681B887' -derivedDataPath /private/tmp/tachobook-swiftdata-build -resultBundlePath /private/tmp/tachobook-swiftdata-review.xcresult -parallel-testing-enabled NO > /private/tmp/tachobook-swiftdata-review.log 2>&1
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path /private/tmp/tachobook-swiftdata-review.xcresult --format json
```

After strengthening the UI saved-time assertions, targeted rerun: exit 0, **1 passed, 0 failures**. Production code was unchanged after the full run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=B63DB03E-4B05-4239-A201-6CCA7681B887' -derivedDataPath /private/tmp/tachobook-swiftdata-build -resultBundlePath /private/tmp/tachobook-swiftdata-relaunch.xcresult -only-testing:TachoBookUITests/ShiftPersistenceUITests -parallel-testing-enabled NO > /private/tmp/tachobook-swiftdata-relaunch.log 2>&1
```

| Acceptance | Evidence |
| --- | --- |
| 06:00 → new container at 10:00 yields 4:00 | `sixAMStartReloadsAtTenAMWithoutDuplicateOrCalendarReset` uses explicit timestamps and a real temporary store |
| Old container released before reopening disk | `withModel` autoreleasepool scopes return only values; each invocation creates a new ShiftStore/ModelContainer |
| Close/Resume, original ID/start, rests, driving edit/delete | `closeResumeEditsAndDeletionSurviveReleasedContainers` |
| Multiple previous periods and persisted empty reset | `archivesAndResetRetainPreviousPeriodsAndPersistEmptyCurrent` |
| Existing start/end deletion commands | `deletingEditableStartAndEndSurvivesReload` |
| Midnight, spring/autumn DST, original timezone | explicit long elapsed query and `absoluteTimestampsAndOriginalTimezoneSurviveDST` |
| JSON import/recovery and no reimport after reset | `legacyJournalImportsOnceWithoutDeletingOrReimportingAfterReset` |
| Bad legacy data / failed disk path / corrupt native store preserved | `unreadableLegacyAndFailedDiskStoreStayLockedAndPreserved`, adapted existing unreadable-storage test |
| Honest empty UI; active/closed/resumed after process death | `testEmptyActiveClosedAndResumedStateAcrossFullProcessRelaunch`, screenshots attached in xcresult |

The corrupt-store test intentionally logs SQLite error 26; it passes by checking the error is surfaced and original bytes are preserved. AppIntents metadata extraction warnings and LLDB version diagnostics did not fail the successful runs. Initial sandbox-only simulator discovery failed with permission/service errors; rerunning with required simulator access succeeded. No signing/project settings were changed.

## Actual app relaunch from production store

Command-driven manual verification used two fresh isolated simulators and synthetic legacy fixtures. These launches used **no test or seed arguments**. The app itself imported the fixtures through production startup; no SQLite edits were made. Before/after screenshots were inspected. Active original start/driving persisted while seconds advanced; closed duty stayed frozen at 5:00 and the ongoing rest remained visible.

Setup commands (returned IDs used below):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl create 'TachoBook SwiftData Manual' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-26-5
# 864A64BA-454C-4CA3-A7E6-E4D94ABDAD20
xcrun simctl create 'TachoBook SwiftData Closed Review' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-26-5
# 5F6C2B8C-9692-471E-9DE7-73F4879492E9
```

Exact active sequence, exit 0 throughout:

```sh
active_sim=864A64BA-454C-4CA3-A7E6-E4D94ABDAD20
xcrun simctl boot "$active_sim"
xcrun simctl bootstatus "$active_sim" -b
xcrun simctl install "$active_sim" /private/tmp/tachobook-swiftdata-build/Build/Products/Debug-iphonesimulator/TachoBook.app
xcrun simctl get_app_container "$active_sim" com.grifano.TachoBook data
active_sandbox=/Users/sorlenko/Library/Developer/CoreSimulator/Devices/864A64BA-454C-4CA3-A7E6-E4D94ABDAD20/data/Containers/Data/Application/B3925855-B75E-4D1C-B628-0B7AD98433BC
python3 docs/swiftdata-persistence/manual_fixture.py seed-active "$active_sandbox" /private/tmp/tachobook-swiftdata-active-fixture.json
xcrun simctl launch "$active_sim" com.grifano.TachoBook
# PID 30161
python3 docs/swiftdata-persistence/manual_fixture.py snapshot "$active_sandbox" docs/swiftdata-persistence/active-before.json
xcrun simctl io "$active_sim" screenshot docs/swiftdata-persistence/active-before.png
xcrun simctl terminate "$active_sim" com.grifano.TachoBook
xcrun simctl launch "$active_sim" com.grifano.TachoBook
# PID 30230 — new process
python3 docs/swiftdata-persistence/manual_fixture.py snapshot "$active_sandbox" docs/swiftdata-persistence/active-after.json
cmp docs/swiftdata-persistence/active-before.json docs/swiftdata-persistence/active-after.json
xcrun simctl io "$active_sim" screenshot docs/swiftdata-persistence/active-after.png
cmp /private/tmp/tachobook-swiftdata-active-fixture.json "$active_sandbox/Library/Application Support/TachoBook/shift-journal-v1.json"
```

Exact closed sequence, exit 0 throughout:

```sh
closed_sim=5F6C2B8C-9692-471E-9DE7-73F4879492E9
xcrun simctl boot "$closed_sim"
xcrun simctl bootstatus "$closed_sim" -b
xcrun simctl install "$closed_sim" /private/tmp/tachobook-swiftdata-build/Build/Products/Debug-iphonesimulator/TachoBook.app
xcrun simctl get_app_container "$closed_sim" com.grifano.TachoBook data
closed_sandbox=/Users/sorlenko/Library/Developer/CoreSimulator/Devices/5F6C2B8C-9692-471E-9DE7-73F4879492E9/data/Containers/Data/Application/07F9EA7E-A458-42BB-A6E3-F0E2E24BBC43
python3 docs/swiftdata-persistence/manual_fixture.py seed-closed "$closed_sandbox" /private/tmp/tachobook-swiftdata-closed-fixture.json
xcrun simctl launch "$closed_sim" com.grifano.TachoBook
# PID 30819
python3 docs/swiftdata-persistence/manual_fixture.py snapshot "$closed_sandbox" docs/swiftdata-persistence/closed-before.json
xcrun simctl io "$closed_sim" screenshot docs/swiftdata-persistence/closed-before.png
xcrun simctl terminate "$closed_sim" com.grifano.TachoBook
xcrun simctl launch "$closed_sim" com.grifano.TachoBook
# PID 30888 — new process
python3 docs/swiftdata-persistence/manual_fixture.py snapshot "$closed_sandbox" docs/swiftdata-persistence/closed-after.json
cmp docs/swiftdata-persistence/closed-before.json docs/swiftdata-persistence/closed-after.json
xcrun simctl io "$closed_sim" screenshot docs/swiftdata-persistence/closed-after.png
cmp /private/tmp/tachobook-swiftdata-closed-fixture.json "$closed_sandbox/Library/Application Support/TachoBook/shift-journal-v1.json"
```

Both comparisons returned exit 0. Each store retained exactly three records: two archived, one current. Native snapshots preserve IDs, absolute timestamps, timezone, driving totals, state, and segment data. The fixture comparisons confirmed unchanged legacy recovery files. Initial ad hoc fixture validation compared UUID text casing and failed for a rest ID; comparing canonical UUID identity corrected that verification-script issue. No app change was needed.

Saved evidence can be checked without a simulator:

```sh
python3 docs/swiftdata-persistence/verify_manual.py
# active: PASS — same IDs/timestamps/state/driving/rests; 3 records, no duplicates
# closed: PASS — same IDs/timestamps/state/driving/rests; 3 records, no duplicates
git diff --check
# exit 0
```

Screenshots: [active before](active-before.png), [active after](active-after.png), [closed before](closed-before.png), [closed after](closed-after.png). JSON files are synthetic review evidence, not real driver data.

## Human review

1. Review the store/schema and one-time JSON import; legacy files should remain intact.
2. Run the automated commands with an available iOS 26.5 simulator and fresh result-bundle paths. Test simulator ID/path values above describe this recorded run.
3. In a normal installation, start a shift, enter driving, terminate/relaunch, then Close, relaunch, Resume, and relaunch again. Verify the same start and entered values. Use a disposable test installation for reset/deletion checks.
4. Approve the separate persistence PR before merge. No merge or post-merge validation has been performed. Physical iPhone/TestFlight testing remains unperformed. Timer PR #3 was already merged before this work started, so there is no waiting timer PR to rebase.
