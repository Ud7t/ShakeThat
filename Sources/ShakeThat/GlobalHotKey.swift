import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut registered through Carbon's `RegisterEventHotKey`.
/// Unlike a global `NSEvent` monitor, this needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Registers `keyCode` (a `kVK_` constant) with Carbon `modifiers` (`optionKey`, `shiftKey`, ...).
    /// Returns nil if another app already owns the combo.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in hotKey.action() }
            return noErr
        }
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPointer, &handlerRef) == noErr else {
            return nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5348_4B54), id: 1) // 'SHKT'
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }
}
