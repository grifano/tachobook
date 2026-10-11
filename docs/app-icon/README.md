# TachoBook app icon

Source: Figma Design System, Filled logo node 8575:391. Color: #116B93.
The approved icon uses the original white symbol and proportions on an opaque square blue background. iOS applies its corner mask.

## Xcode

`TachoBook/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` is the 1024 × 1024 RGB PNG master. Xcode generates iPhone and iPad sizes from it. Dark and tinted slots remain optional and empty; custom appearances have not been designed.

## Exports

`exports/` contains PNG and SVG at 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, and 1024 pixels. PNGs are rendered directly from vectors with lossless compression and no alpha channel.

`exports/AppIcon-iOS-Sizes.svg` contains named vector groups at their actual sizes. Drag this file onto the Figma canvas, or paste its SVG contents, then ungroup the outer layer and export individual size groups as PNG at 1×. Automated insertion into Figma failed due to computer-use window capture/input errors; the original Figma section was not confirmed modified.

## Regenerate

Run `node docs/app-icon/generate.cjs` with Sharp available. Alternatively set `TACHOBOOK_SHARP_MODULE` to an existing Sharp module path. No app dependencies were added.

Apple reference: https://developer.apple.com/documentation/xcode/configuring-your-app-icon
