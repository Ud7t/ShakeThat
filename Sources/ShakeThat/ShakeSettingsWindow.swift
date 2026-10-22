import AppKit
import ShakeCore
import SwiftUI

/// Loads and saves the shake settings file in ~/Library/Application Support/ShakeThat/.
@MainActor
final class ShakeSettingsStore: ObservableObject {
    static let fileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ShakeThat", isDirectory: true)
        .appendingPathComponent("shake-settings.json")

    /// The values last loaded from or saved to the file.
    @Published private(set) var settings = ShakeSettings.defaults
    /// Called whenever `settings` changes, so the shake monitor can pick up new values.
    var onChange: ((ShakeSettings) -> Void)?

    /// Reads the file, writing it out with the defaults first if it doesn't exist yet
    /// so there's always a file to open and edit by hand.
    func reload() {
        if let loaded = ShakeSettings.load(from: Self.fileURL) {
            settings = loaded
        } else if !FileManager.default.fileExists(atPath: Self.fileURL.path) {
            settings = .defaults
            try? settings.save(to: Self.fileURL)
        }
        // An unreadable file is left alone (and the previous values kept) rather than overwritten.
        onChange?(settings)
    }

    func save(_ newSettings: ShakeSettings) throws {
        let clamped = newSettings.clamped()
        try clamped.save(to: Self.fileURL)
        settings = clamped
        onChange?(clamped)
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
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
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
    @State private var errorMessage: String?

    init(store: ShakeSettingsStore, close: @escaping () -> Void) {
        self.store = store
        self.close = close
        _draft = State(initialValue: store.settings)
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

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ShakeSettingsStore.fileURL])
                }
                Button("Defaults") { draft = .defaults }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try store.save(draft)
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
