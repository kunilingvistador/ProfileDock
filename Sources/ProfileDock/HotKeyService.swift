import AppKit
import Carbon
import ProfileDockCore

extension HotKey {
    init(event: NSEvent) {
        self.init(keyCode: UInt32(event.keyCode), modifiers: Self.modifiers(event.modifierFlags))
    }
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        (flags.contains(.control) ? control : 0) | (flags.contains(.option) ? option : 0) |
        (flags.contains(.shift) ? shift : 0) | (flags.contains(.command) ? command : 0)
    }
    var carbonModifiers: UInt32 {
        (modifiers & Self.control != 0 ? UInt32(controlKey) : 0) |
        (modifiers & Self.option != 0 ? UInt32(optionKey) : 0) |
        (modifiers & Self.shift != 0 ? UInt32(shiftKey) : 0) |
        (modifiers & Self.command != 0 ? UInt32(cmdKey) : 0)
    }
    @MainActor var display: String { symbols + keyLabel }
    @MainActor var keyLabel: String {
        if keyCode == 49 { return L("Space", "Пробел") }
        if keyCode >= 123 { return Self.keyLabels[keyCode] ?? "?" }
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else {
            return Self.keyLabels[keyCode] ?? "?"
        }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return Self.keyLabels[keyCode] ?? "?" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var dead: UInt32 = 0
        var count: Int = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                    &dead, characters.count, &count, &characters)
        guard status == noErr, count > 0 else { return Self.keyLabels[keyCode] ?? "?" }
        return String(utf16CodeUnits: characters, count: count).uppercased()
    }
}

@MainActor final class CarbonHotKeyBackend: HotKeyRegistering {
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var installationError: OSStatus = noErr
    var onEvent: ((UInt32, Bool) -> Void)?
    private static let signature: OSType = 0x5044484B

    init() {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        installationError = InstallEventHandler(GetEventDispatcherTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                  identifier.signature == 0x5044484B else { return OSStatus(eventNotHandledErr) }
            let down = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            MainActor.assumeIsolated {
                let owner = Unmanaged<CarbonHotKeyBackend>.fromOpaque(context).takeUnretainedValue()
                owner.onEvent?(identifier.id, down)
            }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ key: HotKey, token: UInt32) throws {
        guard key.isValid else { throw HotKeyError.invalidData }
        guard installationError == noErr else { throw HotKeyError.registrationFailed(installationError) }
        if Self.isReserved(key) { throw HotKeyError.reserved }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(key.keyCode, key.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: token), GetEventDispatcherTarget(),
            UInt32(kEventHotKeyExclusive), &reference)
        guard status == noErr, let reference else { throw HotKeyError.registrationFailed(status) }
        references[token] = reference
    }
    func unregister(token: UInt32) {
        if let reference = references.removeValue(forKey: token) { UnregisterEventHotKey(reference) }
    }
    func shutdown() {
        for token in Array(references.keys) { unregister(token: token) }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
        onEvent = nil
    }
    static func isReserved(_ key: HotKey) -> Bool {
        var values: Unmanaged<CFArray>?
        if CopySymbolicHotKeys(&values) == noErr, let array = values?.takeRetainedValue() as? [[String: Any]] {
            for item in array {
                if (item[kHISymbolicHotKeyEnabled as String] as? NSNumber)?.boolValue == true,
                   (item[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value == key.keyCode,
                   (item[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value == key.carbonModifiers { return true }
            }
        }
        func menuContains(_ menu: NSMenu?) -> Bool {
            guard let menu else { return false }
            return menu.items.contains { item in
                if menuContains(item.submenu) { return true }
                var modifiers = HotKey.modifiers(item.keyEquivalentModifierMask)
                if item.keyEquivalent != item.keyEquivalent.lowercased() { modifiers |= HotKey.shift }
                return !item.keyEquivalent.isEmpty && modifiers == key.modifiers &&
                    [key.keyLabel.lowercased(), HotKey.keyLabels[key.keyCode]?.lowercased()].contains(item.keyEquivalent.lowercased())
            }
        }
        return menuContains(NSApp.mainMenu)
    }
}

@MainActor func hotKeyErrorText(_ error: Error) -> String {
    switch error as? HotKeyError {
    case .reserved:
        return L("This combination is used by macOS or ProfileDock. Choose another.", "Это сочетание используется macOS или ProfileDock. Выберите другое.")
    case .invalidData:
        return L("Use a letter, number or arrow with at least two modifiers, including ⌘ or ⌃.", "Используйте букву, цифру или стрелку и минимум два модификатора, включая ⌘ или ⌃.")
    case .registrationFailed(let code):
        return L("macOS could not register this combination (\(code)). It may be in use. Choose another.", "macOS не удалось зарегистрировать сочетание (\(code)). Возможно, оно занято. Выберите другое.")
    case .unsupportedVersion:
        return L("Hotkey settings were saved by a newer version. The file has been preserved.", "Настройки сочетаний созданы более новой версией. Файл сохранён без изменений.")
    default:
        return L("Hotkey settings could not be saved or loaded. Your previous settings have been preserved.", "Не удалось сохранить или прочитать сочетания. Прежние настройки сохранены.")
    }
}
