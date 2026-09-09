import AppKit
import SwiftUI
import ProfileDockCore

@MainActor struct HotKeyEditor: View {
    @ObservedObject var model: AppModel
    let shortcut: Shortcut
    @Environment(\.dismiss) private var dismiss
    @State private var candidate: HotKey?
    @State private var message: String?
    @State private var hasChanges = false

    init(model: AppModel, shortcut: Shortcut) {
        self.model = model; self.shortcut = shortcut
        _candidate = State(initialValue: model.hotKeyDocument.hotKey(for: shortcut.id))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if let image = model.icon(for: shortcut) { Image(nsImage: image).resizable().frame(width: 46, height: 46) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Keyboard shortcut", "Сочетание клавиш")).font(.title2.weight(.semibold))
                    Text(shortcut.name).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            Text(L("Return to this shortcut’s existing Chrome window from another app.", "Возвращайтесь к привязанному окну Chrome из другого приложения."))
                .font(.callout).foregroundStyle(.secondary)
            HotKeyRecorder(key: candidate, onChange: { key in
                candidate = key; message = model.validateHotKey(key, for: shortcut.id); hasChanges = true
            }, onError: { message = $0 })
                .frame(height: 52)
            Text(L("Click the field, then press a key with at least two modifiers, including ⌘ or ⌃. Example: ⌥⌘1. Esc cancels recording.", "Нажмите на поле и введите клавишу с минимум двумя модификаторами, включая ⌘ или ⌃. Например: ⌥⌘1. Esc отменяет запись."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L("The physical key stays the same when you change keyboard layouts. Its label follows the layout.", "При смене раскладки физическая клавиша остаётся прежней. Меняется только её подпись."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = message ?? model.hotKeyStorageError {
                Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("hotkey-error")
            }
            Label(L("Works while ProfileDock is running in the menu bar. Hotkeys are paused while this editor is open.", "Работает, пока ProfileDock запущен в строке меню. Пока эта панель открыта, сочетания приостановлены."), systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !model.hotKeyDocument.enabled {
                Text(L("Hotkeys are currently turned off. Enable them from More options after saving.", "Сочетания сейчас выключены. После сохранения включите их в дополнительных действиях."))
                    .font(.caption).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Button(L("Remove hotkey", "Убрать сочетание")) { candidate = nil; message = nil; hasChanges = true }
                    .disabled(candidate == nil || model.hotKeyStorageError != nil)
                Spacer()
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Save", "Сохранить")) {
                    if let error = model.saveHotKey(candidate, for: shortcut.id) { message = error }
                    else { dismiss() }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(!hasChanges || message != nil || model.hotKeyStorageError != nil)
            }
        }
        .padding(26).frame(width: 535).fixedSize(horizontal: false, vertical: true)
        .onAppear { model.suspendHotKeys() }
        .onDisappear { model.resumeHotKeys() }
    }
}

@MainActor private struct HotKeyRecorder: NSViewRepresentable {
    let key: HotKey?
    let onChange: (HotKey) -> Void
    let onError: (String) -> Void
    func makeNSView(context: Context) -> RecordingButton {
        let button = RecordingButton()
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        button.target = button; button.action = #selector(RecordingButton.beginRecording)
        button.setAccessibilityLabel(L("Record a keyboard shortcut", "Записать сочетание клавиш"))
        return button
    }
    func updateNSView(_ button: RecordingButton, context: Context) {
        button.key = key; button.onChange = onChange; button.onError = onError
        button.updateTitle()
    }
}

@MainActor private final class RecordingButton: NSButton {
    var key: HotKey?
    var onChange: ((HotKey) -> Void)?
    var onError: ((String) -> Void)?
    private var recording = false
    override var acceptsFirstResponder: Bool { true }
    @objc func beginRecording() { recording = true; window?.makeFirstResponder(self); updateTitle() }
    func updateTitle() {
        title = recording ? L("Press combination…", "Нажмите сочетание…") : key?.display ?? L("Click to record", "Нажмите для записи")
        setAccessibilityValue(title)
    }
    override func resignFirstResponder() -> Bool { recording = false; updateTitle(); return super.resignFirstResponder() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        consume(event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        consume(event)
    }
    private func consume(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 { recording = false; updateTitle(); return }
        if event.keyCode == 48 {
            recording = false; updateTitle()
            if event.modifierFlags.contains(.shift) { window?.selectPreviousKeyView(self) }
            else { window?.selectNextKeyView(self) }
            return
        }
        let key = HotKey(event: event)
        guard key.isValid, !event.modifierFlags.contains(.function) else {
            onError?(hotKeyErrorText(HotKeyError.invalidData)); return
        }
        guard !CarbonHotKeyBackend.isReserved(key) else { onError?(hotKeyErrorText(HotKeyError.reserved)); return }
        recording = false; self.key = key; updateTitle(); onChange?(key)
    }
}
