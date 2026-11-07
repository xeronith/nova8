# AGENTS.md

macOS SwiftUI app. The repo root is the directory containing `project.yml`; `Nova8/` is the app source, not the repo root.

## Build & test

Requires `xcodegen` (`brew install xcodegen`). The deployment target is macOS 15 and the project uses Swift 5 language mode.

Run from the repo root (the directory containing `project.yml`):

```sh
xcodegen generate
xcodebuild -scheme Nova8 -destination 'platform=macOS' build
xcodebuild -scheme Nova8 -destination 'platform=macOS' test
```

Run one test:

```sh
xcodebuild -scheme Nova8 -destination 'platform=macOS' test \
  -only-testing:Nova8Tests/AssemblerTests/testImmediateEncoding
```

- `Nova8.xcodeproj` and `Nova8/Info.plist` are generated. Edit `project.yml`, then re-run `xcodegen generate` after adding/removing files. Never hand-edit `project.pbxproj` or `Info.plist`.
- Keep `PRODUCT_NAME` as `Nova8`. The tests' `TEST_HOST` depends on it; `CFBundleDisplayName` is what shows `NOVA-8`.
- No SPM, lint, formatter, or CI config exists. Use `xcodebuild`, not `swift test`; it is the source of truth.

## Code map

- `Nova8/Engine/` is UI-free (Foundation only): ISA/ALU, micro-op planner, machine clock, snapshots/history, assembler, samples. Keep SwiftUI/AppKit out.
- `Nova8/App/SimulatorModel.swift` is the single `@MainActor @Observable` UI model: run loop, breakpoints, history, file I/O, autosave.
- `Nova8/UI/Datapath/` owns the animated bus; `UI/Panels/`, `UI/Editor/`, and `Theme.swift` own the rest.
- Each micro-op is planned before execution and recorded as a full `MachineSnapshot` (history capped at 2500). Changes to `InstructionPlanner`/`Machine` affect stepping, scrubbing, and time-travel forking — run the full suite.

## Testing quirks

- Tests are app-hosted, so even engine tests build and launch the app.
- Snapshot tests render views offscreen with `NSHostingView` and write PNGs to `$TMPDIR/Nova8Snapshots` (`snapshot-main.png`, `snapshot-main-light.png`, `snapshot-halted.png`, etc.). `screencapture` often fails in this environment; use these snapshots to verify UI. The render helper pins the appearance (`darkAqua` by default), so always pass `appearance: .aqua` when adding a light variant. The suite takes ~10s because it pumps the run loop.
- After a UI change, refresh `Docs/screenshot-dark.png` from `snapshot-main.png` and `Docs/screenshot-light.png` from `snapshot-main-light.png`.
- `SimulatorModel()` reads `~/Library/Application Support/Nova8/last.asm` on launch. Delete it to get the Countdown demo; tests that need deterministic content should load a sample explicitly.

## UI gotchas

- The app follows the system appearance (light/dark). Theme tokens in `Nova8/UI/Theme.swift` are dynamic `NSColor`s that resolve per appearance: use `Theme.*` in SwiftUI and the `.nova*` `NSColor` statics in AppKit. Never hardcode hex values or `Color.white`/`Color.black` in views, or light mode breaks. Don't reintroduce `.preferredColorScheme(.dark)`.
- The AppKit editor resolves dynamic colors at draw time; `CodeTextView.viewDidChangeEffectiveAppearance` forces a redraw so the gutter and attributed text update on a live theme switch.
- Do not bring back `NSRulerView` for the editor gutter. On macOS 15 its scroll-view chrome drew a separator above the editor and through the panel header. The gutter is drawn inside `CodeTextView.drawBackground`, and gutter clicks are handled by `CodeTextView.mouseDown`.
- Keep `CodeTextView` as the scroll view's document view. A custom AppKit sibling gutter previously caused text not to render in offscreen snapshots.
- The app is intentionally not sandboxed so Open/Save and autosave work without prompts. Don't enable the sandbox casually.
- Keyboard shortcuts are declared in `Nova8/App/Nova8App.swift`; keep `README.md` in sync when changing them.

## Conventions

- Use Conventional Commits (`feat:`, `fix(scope):`, `docs:`, `test:`).
- `README.md` is the user-facing ISA/architecture doc; keep it in sync with behavior changes.
