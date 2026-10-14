# Readable time pickers with system dark appearance

Source: Serhii's Day start photo and request in this chat on 2026-10-14. He authorized either dark-mode support or keeping the time text dark. This focused fix uses the latter option.
Executor: Codex. Branch: `codex/light-sheet-picker`.
Base: `4411c35e2414cb1b2c6e8d53270a89d6a15b14f1` (fetched current main).
Separate worktree: `/Users/sorlenko/iOSDev/TachoBook/codex/light-sheet-picker`.

The sheets have fixed white backgrounds, but wheel DatePickers inherited the phone's dark color scheme. Their white digits disappeared on the white surface. Apply `.environment(\.colorScheme, .light)` to the two wheel pickers, in DayStartSheet and DayEndSheet. The selected digits now use native dark text; adjacent values retain native fading. No font, layout, app-wide appearance, data command or persistence change is included.

The existing full-day UI scenario now also expands Day end's wheel and attaches a screenshot before confirming it. No new test case or third-party dependency was added.

## Verification — 2026-10-14

Xcode 26.6 (17F113), iOS 26.5 Simulator, isolated iPhone 17e.

- Before the fix: reproduced the supplied photo under system dark appearance. The existing functional UI test passed, but its expanded Day start screenshot showed invisible digits. Functional pass alone did not prove readability.
- After the fix: the existing full-day UI scenario passed under both dark and light system appearances, **1 execution in each appearance, 0 failures**. Both expanded pickers were visually inspected; dark selected digits and adjacent faded values were readable.
- `git diff --check`: passed.
- Figma Day start reference `284:6175` was inspected through metadata and screenshot. Its white surface and dark labels were preserved. `get_design_context` did not return promptly and was cancelled; no layout, token, asset or font was reimplemented from incomplete context.
- Verification is on Simulator; the user's physical phone has not been retested. Other pre-existing dark-appearance visual differences remain outside this picker fix.

Commands run from the separate worktree:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl create 'TachoBook Picker Dark Review' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-26-5
# D3F14D3B-796E-41D5-A4CE-1174C5364CC5
xcrun simctl boot D3F14D3B-796E-41D5-A4CE-1174C5364CC5
xcrun simctl ui D3F14D3B-796E-41D5-A4CE-1174C5364CC5 appearance dark
xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=D3F14D3B-796E-41D5-A4CE-1174C5364CC5' -derivedDataPath /private/tmp/tachobook-picker-build -resultBundlePath /private/tmp/tachobook-picker-dark-before.xcresult -only-testing:TachoBookUITests/TachoBookUITests/testLogFullDayFlow -parallel-testing-enabled NO > /private/tmp/tachobook-picker-dark-before.log 2>&1
# Before fix: exit 0; screenshot shows the defect.
```

Final dark check after both pickers were expanded in the existing test:

```sh
xcrun simctl ui D3F14D3B-796E-41D5-A4CE-1174C5364CC5 appearance
# dark
xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=D3F14D3B-796E-41D5-A4CE-1174C5364CC5' -derivedDataPath /private/tmp/tachobook-picker-build -resultBundlePath /private/tmp/tachobook-picker-dark-both.xcresult -only-testing:TachoBookUITests/TachoBookUITests/testLogFullDayFlow -parallel-testing-enabled NO > /private/tmp/tachobook-picker-dark-both.log 2>&1
# TEST SUCCEEDED, exit 0, 1 passed, 0 failures.
xcrun xcresulttool export attachments --path /private/tmp/tachobook-picker-dark-both.xcresult --output-path /private/tmp/tachobook-picker-dark-both-attachments
```

Final light check:

```sh
xcrun simctl ui D3F14D3B-796E-41D5-A4CE-1174C5364CC5 appearance light
xcrun simctl ui D3F14D3B-796E-41D5-A4CE-1174C5364CC5 appearance
# light
xcodebuild test -project TachoBook.xcodeproj -scheme TachoBook -destination 'platform=iOS Simulator,id=D3F14D3B-796E-41D5-A4CE-1174C5364CC5' -derivedDataPath /private/tmp/tachobook-picker-build -resultBundlePath /private/tmp/tachobook-picker-light-both.xcresult -only-testing:TachoBookUITests/TachoBookUITests/testLogFullDayFlow -parallel-testing-enabled NO > /private/tmp/tachobook-picker-light-both.log 2>&1
# TEST SUCCEEDED, exit 0, 1 passed, 0 failures.
xcrun xcresulttool export attachments --path /private/tmp/tachobook-picker-light-both.xcresult --output-path /private/tmp/tachobook-picker-light-both-attachments
git diff --check
```

An intermediate run before extending the Day end screenshot also passed: `/private/tmp/tachobook-picker-dark-fixed.xcresult`.

## Screenshots and human review

- [Dark appearance before fix](dark-before.png)
- [Day start, system dark](dark-start-after.png)
- [Day end, system dark](dark-end-after.png)
- [Day start, system light](light-start-after.png)
- [Day end, system light](light-end-after.png)

On the phone, enable system dark appearance, open Day start, tap its time pill, and verify the digits are visible and selectable. Repeat in Day end and confirm a value. The picker should retain the light appearance in either system theme.

Awaiting Serhii's review; no merge performed. Persistence PR #4 and its existing worktree remain separate and unchanged. No Notion task was created or repurposed for this user-reported UI fix.
