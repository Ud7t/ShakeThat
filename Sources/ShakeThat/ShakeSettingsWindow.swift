import AppKit
import ServiceManagement
import ShakeCore
import SwiftUI

/// Loads and saves the shake and drop zone values in the settings file in ~/Library/Application Support/ShakeThat/.
@MainActor
final class ShakeSettingsStore: ObservableObject {
    private static let folderURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ShakeThat", isDirectory: true)
    static let fileURL = folderURL.appendingPathComponent("settings.json")
    /// The file's name before it held more than shake settings.
    private static let oldFileURL = folderURL.appendingPathComponent("shake-settings.json")

    /// The values last loaded from or saved to the file.
    @Published private(set) var settings = ShakeSettings.defaults
    /// Called whenever `settings` changes, so the shake monitor can pick up new values.
    var onChange: ((ShakeSettings) -> Void)?
    @Published private(set) var dropZone = DropZoneSettings.defaults
    /// Called whenever `dropZone` changes.
    var onDropZoneChange: ((DropZoneSettings) -> Void)?

    /// Reads the file, writing it out with the defaults first if it doesn't exist yet
    /// so there's always a file to open and edit by hand.
    func reload() {
        let files = FileManager.default
        if !files.fileExists(atPath: Self.fileURL.path), files.fileExists(atPath: Self.oldFileURL.path) {
            try? files.moveItem(at: Self.oldFileURL, to: Self.fileURL)
        }
        var readable = false
        if let loaded = ShakeSettings.load(from: Self.fileURL) {
            settings = loaded
            readable = true
        } else if !files.fileExists(atPath: Self.fileURL.path) {
            settings = .defaults
            readable = (try? settings.save(to: Self.fileURL)) != nil
        }
        if readable {
            // Add the hand-edited shelf values to the file so they can be found, keeping any already set.
            try? SettingsFile.merge(ShelfSettings.defaults, into: Self.fileURL, onlyMissing: true)
            try? SettingsFile.merge(DropZoneSettings.defaults, into: Self.fileURL, onlyMissing: true)
            dropZone = DropZoneSettings.load(from: Self.fileURL) ?? dropZone
        }
        // An unreadable file is left alone (and the previous values kept) rather than overwritten.
        onChange?(settings)
        onDropZoneChange?(dropZone)
    }

    func save(_ newSettings: ShakeSettings, dropZone newDropZone: DropZoneSettings) throws {
        let clamped = newSettings.clamped()
        try clamped.save(to: Self.fileURL)
        try newDropZone.save(to: Self.fileURL)
        settings = clamped
        dropZone = newDropZone
        onChange?(clamped)
        onDropZoneChange?(newDropZone)
    }
}

/// The "Shake Settings…" window opened from the menu bar.
@MainActor
final class ShakeSettingsWindowController {
    private let store: ShakeSettingsStore
    private var window: NSWindow?

    init(store: ShakeSettingsStore) {
        self.store = store
    }

    func show() {
        // Pick up any hand edits to the file before showing its values.
        store.reload()
        let window = window ?? makeWindow()
        self.window = window
        window.contentViewController = NSHostingController(rootView: ShakeSettingsView(store: store) { [weak window] in
            window?.close()
        })
        window.center()
        // A menu bar app isn't active by default, so activate it or the window opens behind others.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Shake Settings"
        window.isReleasedWhenClosed = false
        return window
    }
}

struct ShakeSettingsView: View {
    @ObservedObject var store: ShakeSettingsStore
    let close: () -> Void
    @State private var draft: ShakeSettings
    @State private var dropZoneDraft: DropZoneSettings
    /// Read from the system rather than the settings file, since it can also be changed in System Settings.
    @State private var launchAtLogin = ShakeSettingsView.isLaunchAtLoginOn
    @State private var errorMessage: String?

    init(store: ShakeSettingsStore, close: @escaping () -> Void) {
        self.store = store
        self.close = close
        _draft = State(initialValue: store.settings)
        _dropZoneDraft = State(initialValue: store.dropZone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                row("Shake distance (points)", value: $draft.minimumTravel, step: 5, fractionDigits: 0)
                LabeledContent("Direction changes") {
                    HStack {
                        TextField("", value: $draft.requiredReversals, format: .number)
                            .frame(width: 60)
                        Stepper("", value: $draft.requiredReversals, in: 1...20).labelsHidden()
                    }
                }
                row("Time window (seconds)", value: $draft.window, step: 0.1, fractionDigits: 2)
                row("Cooldown (seconds)", value: $draft.cooldown, step: 0.1, fractionDigits: 2)
            }

            Text("A shake is this many left/right direction changes, each at least the shake distance, within the time window.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Show a drop zone while dragging files", isOn: $dropZoneDraft.dropZoneEnabled)
            Form {
                Picker("Drop zone position", selection: $dropZoneDraft.dropZonePosition) {
                    ForEach(DropZonePosition.allCases, id: \.self) { position in
                        Text(position.title).tag(position)
                    }
                }
                .disabled(!dropZoneDraft.dropZoneEnabled)
            }
            Text("Drag files toward the zone and it appears. Drop them on it to put them on the shelf without shaking.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Launch at login", isOn: $launchAtLogin)
            if SMAppService.mainApp.status == .requiresApproval {
                Text("Allow ShakeThat in System Settings › General › Login Items to finish turning this on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ShakeSettingsStore.fileURL])
                }
                Button("Defaults") {
                    draft = .defaults
                    dropZoneDraft = .defaults
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try store.save(draft, dropZone: dropZoneDraft)
                        try applyLaunchAtLogin()
                        close()
                    } catch {
                        errorMessage = "Couldn't save: \(error.localizedDescription)"
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    /// Registers or unregisters the app as a login item when the toggle no longer matches the system.
    private func applyLaunchAtLogin() throws {
        guard launchAtLogin != Self.isLaunchAtLoginOn else { return }
        if launchAtLogin {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// On once registered, even while the user still has to allow it in System Settings.
    private static var isLaunchAtLoginOn: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    private func row(_ label: String, value: Binding<Double>, step: Double, fractionDigits: Int) -> some View {
        LabeledContent(label) {
            HStack {
                TextField("", value: value, format: .number.precision(.fractionLength(0...fractionDigits)))
                    .frame(width: 60)
                Stepper("", value: value, step: step).labelsHidden()
            }
        }
    }
}

private extension DropZonePosition {
    var title: String {
        switch self {
        case .notch: return "Top (notch)"
        case .left: return "Left edge"
        case .right: return "Right edge"
        }
    }
}
