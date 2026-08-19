# Working agreements

## Where to work

**Work directly in this checkout — never in a git worktree.** Do not call `EnterWorktree`, and do
not create worktrees with `git worktree add`. If a session starts inside `.claude/worktrees/…`,
leave it (`ExitWorktree`), merge the branch into `main` locally, and carry on here. Background
isolation is switched off for this repo in `.claude/settings.json`
(`"worktree": {"bgIsolation": "none"}`).

Feature work goes on a **named branch off `main`**, committed as it goes, so any direction can be
reviewed or abandoned without losing it. Merge into `main` only when asked.

## Build order

```
docs → test cases → test code → implementation
```

Nothing is implemented before the step above it exists. If the implementation shows the
specification was wrong, correct the document first — see `docs/README.md`.

## Project facts worth not rediscovering

- iPhone only, native SwiftUI, **no backend**: all data and photographs stay on the device.
- `xcodegen generate` must be re-run after adding or deleting any file.
- The four suites: `swift test` on `Packages/FoodMapDomain`, `FoodMapData` and `FoodMapDesign`, and
  `xcodebuild test` for the XCUITest journeys. Prefer `xcodebuild test` over
  `test-without-building`, which happily re-runs a stale bundle.
- `FoodMapUITests/DesignSweep.swift` captures all 13 screens, light and dark, for design review.
- Localisation: every user-facing string is a catalogue key with a Vietnamese translation. A
  ternary of two string literals inside `Text(...)` resolves to `String` and silently skips
  translation — use two `Text`s.
- UI direction: the app must read as an **art-directed object**, not stock SwiftUI. See
  `docs/architecture/adr-003-ui-design.md` and `docs/design/review-2026-08-19.md`.
