# ShakeThat

Free, open-source Dropover alternative for macOS. Shake while dragging to open a floating shelf, then drop files anywhere.

## How it works

1. Start dragging one or more files (from Finder, the Desktop, Mail, anywhere).
2. Shake the cursor left and right a few times. A floating shelf appears under the cursor.
3. Let go to drop the files on the shelf. They stay there while you go find the destination.
4. Drag from the shelf to the destination folder or app. All files on the shelf go together, and the shelf closes once they've landed.

The destination decides what happens to the files, just as with a normal drag: Finder moves them within the same disk and copies them to another disk (hold Option to copy). Cancelling the drag keeps the files on the shelf.

Other bits:

- Click the menu bar icon for **Show Shelf**, **Clear Shelf**, and **Quit**.
- Drag an empty shelf by its background to move it.
- The x button clears the shelf and hides it. It never deletes files; the shelf only holds references.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (or the Swift 5.9+ command line tools) to build

## Build and run

```sh
git clone https://github.com/Ud7t/ShakeThat.git
cd ShakeThat
./scripts/build-app.sh
open build/ShakeThat.app
```

During development you can also run it straight from SwiftPM with `swift run`, or open `Package.swift` in Xcode.

Run the tests with `swift test`.

## Project layout

| Path | What it is |
| --- | --- |
| `Sources/ShakeCore/ShakeDetector.swift` | Pure shake-detection logic (direction reversals within a time window), unit tested |
| `Sources/ShakeThat/DragShakeMonitor.swift` | Global mouse monitor that feeds the detector and checks the drag pasteboard for files |
| `Sources/ShakeThat/ShelfController.swift` | The floating, non-activating panel and where it appears |
| `Sources/ShakeThat/ShelfView.swift` | Drop target and drag source for the files on the shelf |
| `Sources/ShakeThat/AppDelegate.swift` | Menu bar item and wiring |
| `scripts/build-app.sh` | Builds and ad-hoc signs `build/ShakeThat.app` |

## Roadmap ideas

- Settings for shake sensitivity and launch at login
- Dragging out a single file instead of the whole stack
- Multiple shelves, Quick Look, and a keyboard shortcut to open a shelf

## License

MIT, see [LICENSE](LICENSE).
