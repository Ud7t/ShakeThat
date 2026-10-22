# ShakeThat

Free, open-source Dropover alternative for macOS. Shake while dragging to open a floating shelf, then drop files anywhere.

## How it works

1. Start dragging one or more files (from Finder, the Desktop, Mail, anywhere).
2. Shake the cursor left and right a few times. A floating shelf appears under the cursor.
3. Let go to drop the files on the shelf. They stay there while you go find the destination.
4. Drag from the shelf to the destination folder or app. All files on the shelf go together, and the shelf closes once they've landed.

The destination decides what happens to the files, just as with a normal drag: Finder moves them within the same disk and copies them to another disk (hold Option to copy). Cancelling the drag keeps the files on the shelf.

Other bits:

- Click the menu bar icon for **Show Shelf**, **Clear Shelf**, **Shake Settings…**, and **Quit**.
- Shake Settings edits how hard you need to shake: the distance of each stroke, how many direction changes, the time window they must fit in, and a cooldown between shelves. Changes apply as soon as you save. The values live in `~/Library/Application Support/ShakeThat/settings.json`, which you can also edit by hand; reopen Shake Settings (or relaunch) to pick up hand edits.
- Drag the shelf by its edge or label to move it. Dragging the file cards drags the files out.
- The x button clears the shelf and hides it. It never deletes files; the shelf only holds references.
- Right-click (or Control-click) the shelf for quick actions on all of its files: **Copy Path**, **Reveal in Finder**, **Compress** to a zip, and **Move to Folder…**. When there are images on the shelf, **Convert** them to PNG, JPEG, HEIC or TIFF, or **Resize** them to 75%, 50% or 25%. New files are saved next to the originals and never overwrite anything. A zip or converted images take the originals' place on the shelf, and the previous shelf goes into Recent Shelves. Everything runs locally.
- **Recent Shelves** in the menu lists the last 10 shelves that were cleared (with the x, Clear Shelf, or by dragging the files out). Choosing one puts those files back on a shelf, skipping any that no longer exist. Files that were moved are found in their new place. To keep more or fewer, change `recentShelvesLimit` (1 to 100) in `settings.json`; it isn't in the Shake Settings window.

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
| `Sources/ShakeCore/ShakeSettings.swift` | The shake tuning values and their JSON file format, unit tested |
| `Sources/ShakeCore/ShelfSettings.swift` | The hand-edited shelf values in the settings file (`recentShelvesLimit`), unit tested |
| `Sources/ShakeCore/FileNaming.swift` | Names for new files ("photo (50%).png", "Archive 2.zip") that never overwrite, unit tested |
| `Sources/ShakeCore/SettingsFile.swift` | Writes into the shared settings file without dropping other keys, unit tested |
| `Sources/ShakeThat/ShakeSettingsWindow.swift` | The Shake Settings window (SwiftUI) and the settings file in Application Support |
| `Sources/ShakeThat/DragShakeMonitor.swift` | Global mouse monitor that feeds the detector and checks the drag pasteboard for files |
| `Sources/ShakeThat/ShelfController.swift` | The floating, non-activating panel and where it appears |
| `Sources/ShakeThat/ShelfView.swift` | Drop target and drag source for the files on the shelf |
| `Sources/ShakeThat/ShelfActions.swift` | Quick actions: copy paths, reveal, zip, image convert and resize, move to a folder |
| `Sources/ShakeThat/ShelfHistory.swift` | The last 10 cleared shelves, saved as file bookmarks in user defaults |
| `Sources/ShakeThat/RecentShelvesMenu.swift` | The Recent Shelves submenu |
| `Sources/ShakeThat/MenuBarIcon.swift` | Menu bar glyph: the icon's cursor and shake lines, drawn as a template image |
| `Sources/ShakeThat/AppDelegate.swift` | Menu bar item and wiring |
| `Resources/Icon/` | App icon: `ShakeThatIcon.svg` is the source, and `AppIcon-1024.png` is the master the build turns into `AppIcon.icns` |
| `scripts/build-app.sh` | Builds and ad-hoc signs `build/ShakeThat.app` |

## Roadmap ideas

- Launch at login
- Dragging out a single file instead of the whole stack
- Multiple shelves, Quick Look, and a keyboard shortcut to open a shelf

## License

MIT, see [LICENSE](LICENSE).
