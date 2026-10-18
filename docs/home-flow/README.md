# Home flow from Figma — Log Day Shift

Task: [TachoBook — Home Flow from Figma (Log Day Shift)](https://app.notion.com/p/3fddb41bd74b817e8122edebf05944f7)
Executor: Claude Code. Branch: `claude/home-flow-figma`. Base: `e568a5ec74eb08b9085173fc75ac674599b8fd3b` (origin/main).
Figma: [Flow 1 - Log Day Shift, node 490:26251](https://www.figma.com/design/rpZZnwAC53fG7zjQy42Snq/TachoBook--UI-Design?node-id=490-26251).

## Frames: Figma, 402 pt (iPhone 17 Pro), 390 pt (iPhone 16e)

Figma values are sample content. The app shows live values from stored timestamps, so times differ.
Frame 01 at 402/390 uses the DEBUG seed (`-seedHomeFlow`: shift 17.10 05:40–08:34, weekly rest from 08:34),
captured on 18.10 around 14:45. Frames 02–09 come from the UI tests, which seed a weekly rest that ended 46 h ago
(frame 04: a shift started 14 h 45 min ago) and use the current time.

| # | Figma | 402 pt | 390 pt |
|---|---|---|---|
| 01 weekly rest | ![](figma-01.jpg) | ![](01-402.jpg) | ![](01-390.jpg) |
| 01 rest done, Start of day enabled | — | ![](01-ready-402.jpg) | ![](01-ready-390.jpg) |
| 02 shift start sheet | ![](figma-02.jpg) | ![](02-402.jpg) | ![](02-390.jpg) |
| 03 shift started | ![](figma-03.jpg) | ![](03-402.jpg) | ![](03-390.jpg) |
| 04 near the 15 h limit | ![](figma-04.jpg) | ![](04-402.jpg) | ![](04-390.jpg) |
| 05 rest start sheet | ![](figma-05.jpg) | ![](05-402.jpg) | ![](05-390.jpg) |
| 06 driving alert | ![](figma-06.jpg) | ![](06-402.jpg) | ![](06-390.jpg) |
| 07 driving time | ![](figma-07.jpg) | ![](07-402.jpg) | ![](07-390.jpg) |
| 08 daily rest | ![](figma-08.jpg) | ![](08-402.jpg) | ![](08-390.jpg) |
| 09 rest, Work tab | ![](figma-09.jpg) | ![](09-402.jpg) | ![](09-390.jpg) |
| 08 after relaunch | — | ![](08-relaunch-402.jpg) | ![](08-relaunch-390.jpg) |
| Edit Day closed (prefilled) | — | ![](edit-day-closed-402.jpg) | ![](edit-day-closed-390.jpg) |
| Accessibility text size M | — | ![](large-text-ax-402.jpg) | ![](large-text-ax-390.jpg) |

## Contrast update (Serhii's request, 18.10.2026)

Colours darkened so the XCTest accessibility audit passes **every category, contrast included**, in five
states (rest finished, work, daily rest, rest with Work tab, near the 15 h limit) at 402 and 390 pt.

| Element | Figma | Now |
|---|---|---|
| Blue captions and card titles | #116B93 | #083F58 |
| Start of day / End of day fill (white text) | #E8652A | #C4521D |
| Red remaining time | #DE635A | #A3322B |
| Start at / End at text on green | #2D5C40 | #1F4A31 |
| Dimmed Start of day | #BFBFBF on 40 % gray, translucent | #4F4F4F on solid #DBDBDB |
| Week strip neighbours | white at 50 % / 25 % | solid 93 % / 86 % white, darker top scrim |
| Work/Rest toggle | custom, coloured selected label | native segmented control (black selected label) |
| Widget subtitle | 12 pt regular | 12 pt medium |

Gauge arcs, tab bar and icons keep the Figma colours (graphics, not text).

![Before and after: 01 and 08](contrast-01-08.jpg)
![Before and after: 03 and 04](contrast-03-04.jpg)
![Before and after: 09 and 01 rest done](contrast-09-ready.jpg)

Individual "before" captures: `contrast-before/`.

## Work ↔ Rest without layout jump (review fix, 18.10.2026)

Cause: the header icon slot followed the icon size (40 × 40 work, 40 × 27 bed), so the Rest card was
shorter. Measured by `HomeFlowUITests.testToggleDoesNotShiftLayout` (accessibility frames, pt):

| Width | Before: Work / Rest widget height | Before: summary card y (Work / Rest) | After: widget height (Work, Rest, work state) | After: card y |
|---|---|---|---|---|
| 402 pt | 249.00 / 243.67 | 541.67 / 536.33 | 249.00, 249.00, 249.00 | 541.67 in both tabs |
| 390 pt | 249.00 / 243.67 | 526.67 / 521.33 | 249.00, 249.00, 249.00 | 526.67 in both tabs |

Both icons now sit in a fixed 40 × 40 slot; the bed keeps its aspect ratio, centred. 249 pt equals the Figma widget height.

![Work and Rest at 402 and 390 pt](toggle-work-rest.jpg)

## Known visual differences

- Native sheets dim Home behind them; Figma shows no dimming.
- The native iOS 26 alert (frame 06) adapts its glass to the dimmed photo and renders dark; Figma shows a light alert.
- Widgets use a light 80 % fill over a native blur material. Liquid Glass variants rendered too gray or too transparent next to Figma.
- Colours are darker than Figma for contrast (see above).
- The three bed icons under the gauge (reduced-rest counter) and country codes ("F ·", "DE·") are out of scope and not shown.
- Text wraps or the layout stacks at large text sizes; at accessibility sizes the tab bar shows icons only (names stay for VoiceOver and the Large Content Viewer).

## Run the seeded scenario

Debug builds only. The seed never replaces stored data; delete the app first for a clean start.

```sh
xcrun simctl launch --terminate-running-process booted com.grifano.TachoBook -seedHomeFlow
```

In Xcode: Product › Scheme › Edit Scheme › Run › Arguments, add `-seedHomeFlow`.
