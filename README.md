# Altanboard

[![Swift CI](https://github.com/amin-abbasiy/Altanboard/actions/workflows/ci.yml/badge.svg)](https://github.com/amin-abbasiy/Altanboard/actions/workflows/ci.yml)

A minimal native whiteboard for Apple Silicon Macs. Black and red pencils, Command-held drawing, and JSON save/load. No dependencies, accounts, or network access.

## Build

Requires **Apple Silicon, macOS 13+, and Swift 6**.

Without Xcode: install Apple's Command Line Tools (`xcode-select --install`), then run from the project folder:

```sh
bash scripts/build-without-xcode.sh
open build-command-line/Altanboard.app
```

With **Xcode 16+**: open `Altanboard.xcodeproj`, select **Altanboard → My Mac**, and press **⌘R**. Or run `bash scripts/build-macos.sh`.

Builds are locally signed; no developer account needed. Not notarized for distribution.

## Use

- **Draw:** hold **⌘ Command** and move the pointer—no clicking or trackpad pressure needed. Release Command to stop.
- **Cursor:** moving, clicking, or dragging without Command does not draw.
- **Mode indicator:** automatically shows **Cursor mode** or **Paint mode**; it is not a toggle.
- **Colors:** choose black or red in either mode.
- **Save & Clear:** save as JSON, then clear only if saving succeeds.
- **Load:** replace the board with saved JSON. Invalid files leave the current drawing unchanged. Try `Examples/Drawing.json`.
- **Clear:** erase everything.

Each Command hold starts a separate stroke. Leaving the canvas or switching apps ends the current stroke, preventing connecting lines across gaps. Resizing preserves drawing proportions.

**No autosave or undo.** Clearing, loading, or closing discards unsaved work without confirmation.

## Tests

```sh
swift test -Xswiftc -warnings-as-errors
swift scripts/verify-project.swift
```

Native app tests: **⌘U** in Xcode or `bash scripts/test-macos.sh` (requires full Xcode).

## License

[MIT](LICENSE)
