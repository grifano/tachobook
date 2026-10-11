# TachoBook — Agent Instructions

## Project

TachoBook is a native iOS app built with Swift and SwiftUI.

The Figma design is the visual source of truth for UI implementation.

Figma file:
https://www.figma.com/design/rpZZnwAC53fG7zjQy42Snq/TachoBook--UI-Design

Use the local `figma-desktop` MCP server whenever implementation depends on Figma.

## Core workflow

For new screens, flows, or meaningful feature work:

1. Inspect the relevant Figma node using Figma MCP.
2. Inspect the existing project structure and reusable components.
3. Create a short implementation plan before coding.
4. Implement using native SwiftUI.
5. Add or update tests for meaningful logic.
6. Build and run relevant tests.
7. Compare the implementation against the Figma screenshot/context.
8. Fix visual or behavioral mismatches before declaring the task complete.

For small isolated fixes, keep the process proportional and avoid unnecessary planning overhead.

## Skills

Use relevant installed skills when applicable:

- `figma` and `figma-implement-design` for Figma-to-code work.
- `swiftui-pro` for SwiftUI implementation and review.
- `swift-testing-pro` for Swift Testing.
- `swiftdata-pro` when persistence using SwiftData is actually required.
- `test-driven-development` for logic-heavy or behavior-driven implementation.
- `systematic-debugging` when diagnosing defects.
- `code-review` for final review of significant changes.
- `security-best-practices` when handling sensitive data, permissions, storage, networking, or security-sensitive code.
- `verification-before-completion` before claiming meaningful work is complete.
- `writing-plans` for substantial tasks.
- `brainstorming` only when requirements or product behavior are unclear.

Do not invoke skills mechanically when they do not add value.

## Figma rules

- Do not redesign approved UI unless explicitly asked.
- Do not invent spacing, typography, colors, icons, states, or behavior when Figma contains the answer.
- Use design context and screenshots rather than relying only on visual guessing.
- Reuse existing project components where they can accurately represent the design.
- Do not modify the Figma file unless explicitly requested.
- Read-only Figma MCP operations are allowed for implementation and verification.
- Treat dates, times, names, counts, and other values shown in Figma as sample design content unless requirements explicitly define them as fixed data.
- Runtime values should come from the app state or current system data, not be copied from the Figma mockup.

## Adaptive layout

Figma frame dimensions represent the reference viewport, not fixed runtime dimensions.

- Never hardcode the source device width (for example 402 pt) into production SwiftUI layout.
- Translate Figma container widths into layout relationships.
- Example: a 370 pt container inside a 402 pt screen means 16 pt horizontal margins, not `.frame(width: 370)`.
- Full-width cards, sheets, buttons, and navigation containers must adapt using available width and semantic padding.
- Respect safe areas.
- Fixed dimensions are appropriate only for intrinsically fixed elements such as icons, controls, and specific visual indicators.
- Verify layouts at multiple iPhone widths before completion.

## Swift / SwiftUI

- Prefer native SwiftUI and current Apple APIs.
- Keep views small and composable.
- Keep business logic out of large view bodies.
- Avoid unnecessary abstractions and architecture layers.
- Do not add third-party dependencies unless they are clearly necessary and approved.
- Preserve the project's existing deployment target and Swift settings unless explicitly asked to change them.
- Follow accessibility best practices, including Dynamic Type and VoiceOver where applicable.
- Prefer the native SwiftUI system font for Apple system typography. Do not recreate SF Pro using custom font files unless the design explicitly requires a non-system typeface.
- When Figma shows glass/material effects, use the appropriate native SwiftUI material or Liquid Glass API supported by the project's deployment target, with a compatibility fallback when necessary.

## State and data

- Use the simplest state model that correctly represents the feature.
- Do not introduce SwiftData until persistence is required.
- Keep derived values derived instead of duplicating stored state where practical.

## Testing

- Use Swift Testing for unit and logic tests.
- Use XCTest for UI tests.
- Test meaningful behavior and calculations rather than implementation details.
- Before finishing a substantial task, run the relevant build and tests.

## Change discipline

- Do not modify unrelated files.
- Do not perform broad refactors while implementing a focused feature unless required.
- Do not silently change product behavior.
- If Figma, requirements, and existing code conflict, stop and explain the conflict before choosing one.
- Prefer the smallest implementation that satisfies the approved behavior and design.

## Completion criteria

Do not state that a meaningful feature is complete until:

- the project builds,
- relevant tests pass,
- the intended flow works,
- the implementation has been checked against Figma,
- and no known in-scope issue remains unresolved.
