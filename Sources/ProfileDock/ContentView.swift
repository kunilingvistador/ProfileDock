import AppKit
import SwiftUI
import ProfileDockCore

private enum DockStyle {
    static let accent = Color.accentColor
    static let border = Color(nsColor: .separatorColor).opacity(0.55)
    static let muted = Color.secondary
}

private struct ShortcutGridFocus: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            // The selected card already provides a focus indicator.
            content.focusEffectDisabled()
        } else { content }
    }
}

private struct ShortcutControlStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private enum EditorRoute: Identifiable {
    case create, edit(Shortcut), relink(Shortcut), favicon(Shortcut), hotkey(Shortcut), help, privacy, project(ProjectSection)
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let shortcut): return "edit-\(shortcut.id)"
        case .relink(let shortcut): return "relink-\(shortcut.id)"
        case .favicon(let shortcut): return "favicon-\(shortcut.id)"
        case .hotkey(let shortcut): return "hotkey-\(shortcut.id)"
        case .help: return "help"
        case .privacy: return "privacy"
        case .project(let section): return "project-\(section.rawValue)"
        }
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @FocusState private var listHasFocus: Bool
    @State private var route: EditorRoute?
    @State private var hoveredShortcutID: UUID?
    @State private var previousVisibleIDs: [UUID] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filteredShortcuts: [Shortcut] {
        let query = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? model.shortcuts : model.shortcuts.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let error = model.hotKeyStorageError {
                Label(error, systemImage: "keyboard.badge.ellipsis")
                    .font(.callout).foregroundStyle(.orange).padding(.horizontal, 28).padding(.bottom, 12)
            }
            if model.legacyLauncherCount > 0 || model.launcherMaintenanceNotice != nil || !model.launcherMaintenanceFailures.isEmpty {
                launcherMaintenanceBanner
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
            }
            if model.shortcuts.isEmpty {
                onboarding
            } else {
                library
            }
            statusFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(DockStyle.accent)
        .frame(minWidth: 800, minHeight: 560)
        .sheet(item: $route, onDismiss: restoreManagerFocus) { selectedRoute in
            switch selectedRoute {
            case .create:
                ShortcutEditor(model: model, shortcut: nil)
            case .edit(let shortcut):
                ShortcutEditor(model: model, shortcut: shortcut)
            case .relink(let shortcut):
                WindowLinkSheet(model: model, shortcut: shortcut)
            case .favicon(let shortcut):
                FaviconSheet(model: model, shortcut: shortcut)
            case .hotkey(let shortcut):
                HotKeyEditor(model: model, shortcut: shortcut)
            case .help:
                HelpSheet(model: model)
            case .privacy:
                PrivacySheet(model: model)
            case .project(let section):
                ProjectPanel(model: model, selection: section,
                             onRelink: { route = .relink($0) }, onPrivacy: { route = .privacy })
            }
        }
        .onChange(of: model.managerCommandRequest) { command in
            guard let command else { return }
            model.managerCommandRequest = nil
            guard route == nil else { return }
            switch command {
            case .create: route = .create
            case .editSelected:
                if let shortcut = filteredShortcuts.first(where: { $0.id == model.selectedShortcutID }) { route = .edit(shortcut) }
            case .help: route = .help
            case .privacy: route = .privacy
            }
        }
        .onAppear { reconcileSelection() }
        .onChange(of: filteredShortcuts.map(\.id)) { _ in reconcileSelection() }
        .onChange(of: model.selectedShortcutID) { _ in reconcileSelection() }
        .onChange(of: model.searchFieldFocused) { focused in
            if focused { listHasFocus = false }
        }
        .onExitCommand {
            if !model.searchText.isEmpty { model.searchText = ""; listHasFocus = true }
        }
        .onChange(of: model.projectSectionRequest) { section in
            if let section {
                model.projectSectionRequest = nil
                if route == nil { route = .project(section) }
            }
        }
        .alert(L("Something needs attention", "Нужна небольшая проверка"), isPresented: Binding(
            get: { model.errorMessage != nil && route == nil },
            set: { if !$0 { model.errorMessage = nil; model.recoveryShortcutID = nil } }
        )) {
            if let shortcut = model.shortcuts.first(where: { $0.id == model.recoveryShortcutID }) {
                Button(L("Choose window", "Выбрать окно")) {
                    model.errorMessage = nil; model.recoveryShortcutID = nil
                    route = .relink(shortcut)
                }
            }
            Button(L("OK", "Понятно"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Text(L("Shortcuts", "Ярлыки")).font(.system(size: 14, weight: .semibold))
            Text("\(filteredShortcuts.count)")
                .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            if model.demoMode {
                Text(L("Local preview", "Локальный предпросмотр"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    private var launcherMaintenanceBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(DockStyle.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                if model.legacyLauncherCount > 0 {
                    Text(L("Older shortcuts: \(model.legacyLauncherCount)", "Старые ярлыки: \(model.legacyLauncherCount)"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("Update your older shortcuts so they can receive fixes through ProfileDock. Their names, pictures and Dock positions stay the same.", "Обновите старые ярлыки, чтобы они получали исправления через ProfileDock. Имена, картинки и места в Dock сохранятся."))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let message = model.launcherMaintenanceNotice {
                    Text(message).fixedSize(horizontal: false, vertical: true)
                }
                if !model.launcherMaintenanceFailures.isEmpty {
                    DisclosureGroup(L("Update details", "Подробности обновления")) {
                        ScrollView {
                            Text(model.launcherMaintenanceFailures.joined(separator: "\n"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 90)
                        .padding(.top, 5)
                    }
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.legacyLauncherCount > 0 || !model.launcherMaintenanceFailures.isEmpty {
                Button(L("Update shortcuts", "Обновить ярлыки")) { model.updateLaunchers() }
                    .buttonStyle(.bordered)
                    .disabled(model.demoMode || model.isBusy || model.isMaintainingLaunchers)
            }
            if model.launcherMaintenanceNotice != nil || !model.launcherMaintenanceFailures.isEmpty {
                Button { model.dismissLauncherMaintenanceNotice() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L("Dismiss", "Скрыть"))
                .accessibilityLabel(L("Dismiss update message", "Скрыть сообщение об обновлении"))
            }
        }
        .padding(12)
        .background(DockStyle.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var onboarding: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(colors: [DockStyle.accent.opacity(0.13), Color.cyan.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 140, height: 110)
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(DockStyle.accent)
                }
                VStack(spacing: 8) {
                    Text(L("Less searching. More doing.", "Меньше поиска. Больше дела."))
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text(L("Choose an open Chrome window, give it a name,\nand keep its shortcut in your Dock.", "Выберите открытое окно Chrome, дайте ему имя\nи сохраните его ярлык в Dock."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                HStack(spacing: 9) {
                    if !model.permissionGranted || !model.chromeRunning {
                        Button { Task { await model.connect() } } label: {
                            Label(L("Connect Chrome", "Подключить Chrome"), systemImage: "link")
                                .padding(.horizontal, 5).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    } else {
                        Button { route = .create } label: {
                            Label(L("Create first shortcut", "Создать первый ярлык"), systemImage: "plus")
                                .padding(.horizontal, 5).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("n", modifiers: .command)
                    }
                    if model.isBusy { ProgressView().controlSize(.small) }
                }
                Button(L("Why does it need access to Chrome?", "Зачем нужен доступ к Chrome?")) { route = .privacy }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                if !model.chromeRunning {
                    Text(L("Open Chrome with the profiles you use, then connect it here.", "Откройте Chrome с нужными профилями, затем подключите его здесь."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(L("Already have ProfileDock shortcuts? Import them", "Уже есть готовые ярлыки? Импортировать")) { model.importExisting() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                Spacer(minLength: 8)
                Label(L("Your profiles and pictures stay on this Mac.", "Профили и изображения хранятся на этом Mac."), systemImage: "lock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var library: some View {
        VStack(spacing: 0) {
            if !model.permissionGranted || !model.chromeRunning {
                HStack(spacing: 10) {
                    Image(systemName: "link").foregroundStyle(.secondary)
                    Text(model.chromeRunning
                         ? L("Connect Chrome to see your open windows.", "Подключите Chrome, чтобы увидеть открытые окна.")
                         : L("Open Chrome, then connect it here.", "Откройте Chrome, затем подключите его здесь."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Connect", "Подключить")) { Task { await model.connect() } }
                        .disabled(model.isBusy)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }

            if filteredShortcuts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(DockStyle.accent)
                        .frame(width: 64, height: 64)
                        .background(DockStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityHidden(true)
                    Text(L("No matching shortcuts", "Ничего не нашлось"))
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text(L("Try another name or clear your search to see all shortcuts.", "Попробуйте другое имя или очистите поиск, чтобы увидеть все ярлыки."))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    Button(L("Clear search", "Очистить поиск")) { model.searchText = "" }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(filteredShortcuts) { shortcut in
                                shortcutCard(shortcut)
                                    .id(shortcut.id)
                                    .contextMenu { shortcutActions(shortcut) }
                            }
                            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button { route = .create } label: {
                                    VStack(spacing: 9) {
                                        Image(systemName: "plus.circle").font(.system(size: 24, weight: .light))
                                        Text(L("Add shortcut", "Добавить ярлык")).font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).frame(height: 106)
                                    .contentShape(RoundedRectangle(cornerRadius: 16))
                                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DockStyle.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                                }
                                .buttonStyle(.plain).disabled(model.isBusy)
                            }
                        }
                        .padding(.horizontal, 22).padding(.top, 3).padding(.bottom, 16)
                    }
                    .focusable()
                    .modifier(ShortcutGridFocus())
                    .focused($listHasFocus)
                    .onAppear {
                        if !model.searchFieldFocused && route == nil { listHasFocus = true }
                    }
                    .onMoveCommand { direction in moveSelection(direction) }
                    .onChange(of: model.searchText) { _ in
                        if let first = filteredShortcuts.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                    .onChange(of: model.selectedShortcutID) { id in
                        if let id { proxy.scrollTo(id) }
                    }
                    .accessibilityLabel(L("Chrome window shortcuts", "Ярлыки окон Chrome"))
                    .background {
                        if route == nil {
                            Button(L("Activate selected shortcut", "Переключить выбранный ярлык")) {
                                guard let shortcut = filteredShortcuts.first(where: { $0.id == model.selectedShortcutID }) else { return }
                                activate(shortcut)
                            }
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(model.isBusy || model.selectedShortcutID == nil)
                            .hidden().accessibilityHidden(true).frame(width: 0, height: 0)
                        }
                    }
                }

            }

        }
    }

    private var statusFooter: some View {
        HStack(spacing: 10) {
            Group {
                if model.isBusy { ProgressView().controlSize(.small) }
                else { Image(systemName: model.notice == nil ? "lock.shield" : "info.circle") }
            }
            .font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                if let notice = model.notice, !notice.isEmpty {
                    Text(notice).font(.system(size: 12)).lineLimit(2)
                        .foregroundStyle(.primary).textSelection(.enabled).help(notice)
                } else {
                    Text(model.isBusy ? L("Updating…", "Обновляем…") : L("Works locally", "Работает локально"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    if !model.shortcuts.isEmpty {
                        Text(L("Arrow keys to select · ↩ Switch", "Стрелки — выбор · ↩ Переключить"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.notice != nil {
                Button { model.notice = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 26)
                }
                .buttonStyle(ShortcutControlStyle())
                .foregroundStyle(.secondary)
                .help(L("Dismiss message", "Скрыть сообщение"))
                .accessibilityLabel(L("Dismiss message", "Скрыть сообщение"))
            }
            Button { route = .project(.feedback) } label: {
                Label(L("Feedback", "Отзыв"), systemImage: "bubble.left")
            }.buttonStyle(ShortcutControlStyle()).font(.system(size: 12)).foregroundStyle(.secondary)
            Button { route = .project(model.showsSupportPrototype ? .support : .status) } label: {
                Label(model.showsSupportPrototype ? L("Support", "Поддержать") : L("Status", "Состояние"),
                      systemImage: model.showsSupportPrototype ? "heart" : "checkmark.shield")
                    .font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                    .modifier(DockGlass())
            }.buttonStyle(ShortcutControlStyle()).padding(.leading, 6)
        }
        .frame(height: 44)
        .padding(.horizontal, 22).padding(.vertical, 10)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func reconcileSelection() {
        let ids = filteredShortcuts.map(\.id)
        if !ids.contains(where: { $0 == model.selectedShortcutID }) {
            let oldIndex = previousVisibleIDs.firstIndex(where: { $0 == model.selectedShortcutID }) ?? 0
            model.selectedShortcutID = ids.isEmpty ? nil : ids[min(oldIndex, ids.count - 1)]
        }
        previousVisibleIDs = ids
    }

    private func restoreManagerFocus() {
        guard route == nil else { return }
        reconcileSelection()
        listHasFocus = false
        // Wait for AppKit to finish detaching the sheet before requesting a
        // toolbar field or a SwiftUI card as the new first responder.
        DispatchQueue.main.async {
            guard route == nil else { return }
            if filteredShortcuts.isEmpty { model.didRequestSearchFocus?() }
            else { listHasFocus = true }
        }
    }

    private func activate(_ shortcut: Shortcut) {
        guard route == nil, !model.isBusy,
              filteredShortcuts.contains(where: { $0.id == shortcut.id }) else { return }
        model.selectedShortcutID = shortcut.id
        switch model.status(for: shortcut) {
        case .ready: Task { await model.switchTo(shortcut) }
        case .missing, .ambiguous: route = .relink(shortcut)
        case .disconnected, .checking: route = .project(.status)
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard route == nil, !filteredShortcuts.isEmpty else { return }
        let current = filteredShortcuts.firstIndex(where: { $0.id == model.selectedShortcutID }) ?? 0
        let offset: Int
        switch direction {
        case .left: offset = -1
        case .right: offset = 1
        case .up: offset = -2
        case .down: offset = 2
        @unknown default: return
        }
        let next = min(max(current + offset, 0), filteredShortcuts.count - 1)
        model.selectedShortcutID = filteredShortcuts[next].id
    }

    private func select(_ shortcut: Shortcut) {
        guard route == nil else { return }
        model.selectedShortcutID = shortcut.id
        // Re-enter SwiftUI's focus tree after using the native toolbar search.
        listHasFocus = false
        DispatchQueue.main.async { if route == nil { listHasFocus = true } }
    }

    private func shortcutCard(_ shortcut: Shortcut) -> some View {
        let status = model.status(for: shortcut)
        let recover = status == .missing || status == .ambiguous
        let selected = model.selectedShortcutID == shortcut.id
        let hovered = hoveredShortcutID == shortcut.id
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    ShortcutAvatar(image: model.icon(for: shortcut), name: shortcut.name, size: 48)
                        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shortcut.name).font(.system(size: 15, weight: .semibold))
                            .lineLimit(1).help(shortcut.name)
                        HStack(spacing: 5) {
                            Image(systemName: status == .ready ? "checkmark.circle.fill" : recover ? "link.badge.plus" : "circle.dotted")
                                .font(.system(size: 10))
                                .foregroundStyle(status == .ready ? Color.green : recover ? Color.orange : Color.secondary)
                                .accessibilityHidden(true)
                            Text(statusLabel(status)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).help(statusLabel(status))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { activate(shortcut) }
                .simultaneousGesture(TapGesture().onEnded { select(shortcut) })
                Menu { shortcutActions(shortcut) } label: {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 28)
                }
                .menuStyle(.borderlessButton).fixedSize().tint(.secondary)
                .help(L("Shortcut actions", "Действия с ярлыком"))
                .accessibilityLabel(L("Options for \(shortcut.name)", "Действия с ярлыком \(shortcut.name)"))
            }
            HStack {
                Button { model.selectedShortcutID = shortcut.id; route = .hotkey(shortcut) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "keyboard").font(.system(size: 11))
                        Text(model.hotKeyDocument.hotKey(for: shortcut.id)?.display ?? L("Set hotkey", "Назначить клавиши"))
                            .font(.system(size: 11, design: model.hotKeyDocument.hotKey(for: shortcut.id) == nil ? .default : .monospaced))
                    }
                    .foregroundStyle(model.hotKeyFailures[shortcut.id] == nil ? Color.secondary : Color.orange)
                    .padding(.horizontal, 8).frame(height: 26)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(ShortcutControlStyle())
                .help(model.hotKeyFailures[shortcut.id] ?? L("Set keyboard shortcut", "Назначить сочетание клавиш"))
                .accessibilityLabel(L("Hotkey for \(shortcut.name): \(model.hotKeyDescription(for: shortcut))", "Сочетание для \(shortcut.name): \(model.hotKeyDescription(for: shortcut))"))
                Spacer(minLength: 8)
                Button { activate(shortcut) } label: {
                    HStack(spacing: 5) {
                        Text(recover ? L("Choose window", "Выбрать окно") : L("Switch", "Переключить"))
                        Image(systemName: recover ? "link" : "arrow.up.forward").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 9).frame(height: 26)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.accentColor : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(ShortcutControlStyle())
                .disabled(model.isBusy || (!recover && status != .ready))
                .accessibilityLabel(recover ? L("Choose a window for \(shortcut.name)", "Выбрать окно для \(shortcut.name)") : L("Switch to \(shortcut.name)", "Переключиться на \(shortcut.name)"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity).frame(height: 106)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).fill(selected ? Color.accentColor.opacity(0.035) : hovered ? Color.primary.opacity(0.025) : .clear).allowsHitTesting(false))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.accentColor.opacity(0.6) : hovered ? Color.primary.opacity(0.20) : DockStyle.border, lineWidth: selected ? 1.5 : 1))
        .shadow(color: .black.opacity(selected || hovered ? 0.045 : 0.018), radius: 6, y: 2)
        .onHover { inside in
            if inside { hoveredShortcutID = shortcut.id }
            else if hoveredShortcutID == shortcut.id { hoveredShortcutID = nil }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: Text(recover ? L("Choose window", "Выбрать окно") : L("Switch", "Переключить"))) { activate(shortcut) }
    }

    private func statusLabel(_ status: ShortcutStatus) -> String {
        switch status {
        case .ready: return L("Window ready", "Окно готово")
        case .missing: return L("Choose an open window", "Выберите открытое окно")
        case .ambiguous: return L("Several windows match", "Совпало несколько окон")
        case .disconnected: return L("Connect Chrome to check", "Подключите Chrome для проверки")
        case .checking: return L("Checking connection…", "Проверяем подключение…")
        }
    }

    @ViewBuilder private func shortcutActions(_ shortcut: Shortcut) -> some View {
        Button(L("Edit shortcut…", "Настроить ярлык…")) { route = .edit(shortcut) }
        Button(L("Keyboard shortcut…", "Сочетание клавиш…")) { route = .hotkey(shortcut) }
        Button(L("Choose another window…", "Привязать другое окно…")) { route = .relink(shortcut) }
        Divider()
        Button(L("Choose picture…", "Выбрать изображение…")) { model.chooseImage(for: shortcut) }
        Button(L("Use a website icon…", "Взять значок сайта…")) { route = .favicon(shortcut) }
        Divider()
        Button(L("Create Dock shortcut", "Создать ярлык для Dock")) { model.exportShortcut(shortcut) }
        Divider()
        Button(L("Remove shortcut", "Удалить ярлык"), role: .destructive) { model.removeShortcut(shortcut) }
    }

}

private struct ShortcutAvatar: View {
    let image: NSImage?
    let name: String
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.39, weight: .bold, design: .rounded))
                    .foregroundStyle(DockStyle.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DockStyle.accent.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
    }
}

@MainActor
private struct ShortcutEditor: View {
    @ObservedObject var model: AppModel
    let shortcut: Shortcut?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var profileID: String?
    @State private var windowID: String?
    @State private var showingFavicon = false
    @State private var isSaving = false

    init(model: AppModel, shortcut: Shortcut?) {
        self.model = model
        self.shortcut = shortcut
        _name = State(initialValue: shortcut?.name ?? "")
        _profileID = State(initialValue: shortcut?.profileDirectory)
    }

    private var profile: BrowserProfile? { model.profiles.first { $0.id == profileID } }
    private var selectedWindow: BrowserWindow? { model.linkableWindows().first { $0.id == windowID } }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (shortcut != nil || selectedWindow != nil) && !model.isBusy && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: shortcut == nil ? L("A new place in your Dock", "Новое место в вашем Dock") : L("Make it yours", "Настройте под себя"), subtitle: shortcut == nil ? L("Link a shortcut to an open Chrome window.", "Свяжите ярлык с открытым окном Chrome.") : L("A clear name and picture make switching easier.", "Понятное имя и картинка помогают быстро найти нужное."))

            Form {
                if shortcut == nil {
                    Section {
                        WindowPicker(model: model, selection: $windowID)
                    } header: {
                        Text(L("1. Choose and check a window", "1. Выберите и проверьте окно"))
                    } footer: {
                        Text(L("Show the window to check its profile before linking it.", "Покажите окно и проверьте его профиль перед привязкой."))
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Shortcut name", "Название ярлыка"))
                            .font(.system(size: 12, weight: .medium))
                        TextField(L("Shortcut name", "Название ярлыка"), text: $name)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(L("Shortcut name", "Название ярлыка"))
                            .onSubmit { if isValid { save() } }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    if shortcut == nil {
                        Picker(L("Name and photo from profile", "Имя и фото из профиля"), selection: $profileID) {
                            Text(L("No profile selected", "Без выбора профиля")).tag(nil as String?)
                            ForEach(model.profiles) { profile in
                                Text(profile.account.map { "\(profile.name) — \($0)" } ?? profile.name)
                                    .tag(Optional(profile.id))
                            }
                        }
                        .onChange(of: profileID) { _ in
                            if let profile { name = profile.name }
                        }
                    }
                } header: {
                    Text(shortcut == nil ? L("2. Name your shortcut", "2. Назовите ярлык") : L("Appearance", "Внешний вид"))
                } footer: {
                    if shortcut == nil {
                        Text(L("Optional: use a profile's name and photo. This does not change the selected window.", "Необязательно: можно взять имя и фото профиля. Выбранное окно от этого не меняется."))
                    }
                }

                if let shortcut {
                    Section {
                        HStack(spacing: 16) {
                            ShortcutAvatar(image: model.icon(for: model.shortcuts.first { $0.id == shortcut.id } ?? shortcut), name: name, size: 64)
                            VStack(alignment: .leading, spacing: 8) {
                                Button(L("Choose picture…", "Выбрать изображение…")) { model.chooseImage(for: shortcut) }
                                Button(L("Use a website icon…", "Взять значок сайта…")) { showingFavicon = true }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    } header: {
                        Text(L("Shortcut picture", "Изображение ярлыка"))
                    }
                } else {
                    Section {
                        Label(L("You can add a photo or website icon after creating the shortcut.", "После создания можно добавить свою фотографию или значок сайта."), systemImage: "photo")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(isSaving)

            SheetFooter(isBusy: model.isBusy || isSaving, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(isSaving)
                Button(shortcut == nil ? L("Create shortcut", "Создать ярлык") : L("Save", "Сохранить")) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .frame(width: 555, height: shortcut == nil ? 595 : 440)
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $showingFavicon) {
            if let shortcut { FaviconSheet(model: model, shortcut: shortcut) }
        }
    }

    private func save() {
        // Reserve before scheduling the main-actor task. Two queued button or
        // Return events must not submit the same editor while Chrome responds.
        guard isValid else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            guard !model.isBusy else { return }
            if let shortcut {
                await model.updateShortcut(shortcut, name: name)
                if model.errorMessage == nil { dismiss() }
            } else if let selectedWindow {
                if await model.addShortcut(name: name, window: selectedWindow, profile: profile) { dismiss() }
            }
        }
    }
}

@MainActor
private struct WindowPicker: View {
    @ObservedObject var model: AppModel
    @Binding var selection: String?
    var shortcutID: UUID? = nil
    private var windows: [BrowserWindow] { model.linkableWindows(for: shortcutID) }
    private var hasDuplicateLabels: Bool { Set(windows.map(\.label)).count != windows.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if !model.permissionGranted || !model.chromeRunning {
                HStack {
                    Text(model.chromeRunning
                         ? L("Connect Chrome to choose a window.", "Подключите Chrome для выбора окна.")
                         : L("Open Chrome, then connect it here.", "Откройте Chrome, затем подключите его здесь."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Connect", "Подключить")) { Task { await model.connect() } }
                        .disabled(model.isBusy)
                }
            } else if windows.isEmpty {
                Text(L("No unlinked windows. Open the Chrome window you want to add, then refresh.", "Свободных окон нет. Откройте нужное окно Chrome и обновите список."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                Picker(L("Open window", "Открытое окно"), selection: $selection) {
                    Text(L("Choose a window…", "Выберите окно…")).tag(nil as String?)
                    ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                        Text("\(index + 1). \(windowLabel(window))")
                            .tag(Optional(window.id))
                    }
                }
                HStack {
                    Button {
                        guard let window = windows.first(where: { $0.id == selection }) else { return }
                        Task { await model.previewWindow(window) }
                    } label: {
                        Label(L("Show window", "Показать окно"), systemImage: "eye")
                    }
                    .disabled(model.isBusy || !windows.contains { $0.id == selection })
                    .help(L("Check the window in Chrome without linking it yet", "Проверить окно в Chrome без изменения привязки"))
                    if model.isBusy { ProgressView().controlSize(.small) }
                }
                if let selected = windows.first(where: { $0.id == selection }), selected.minimized {
                    Label(L("This window is minimized. The shortcut will restore it.", "Это окно свёрнуто. Ярлык развернёт его."), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if hasDuplicateLabels {
                    Label(L("Some titles match. Select a numbered window and use Show window to check it.", "Есть одинаковые названия. Выберите окно по номеру и нажмите «Показать окно», чтобы проверить его."), systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button { Task { await model.refresh() } } label: {
                Label(L("Refresh windows", "Обновить список окон"), systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.link)
            .disabled(model.isBusy)
        }
        .onChange(of: windows) { available in
            if !available.contains(where: { $0.id == selection }) { selection = nil }
        }
    }

    private func windowLabel(_ window: BrowserWindow) -> String {
        if let shortcut = model.shortcuts.first(where: { $0.windowName == window.givenName }) { return shortcut.name }
        return window.label.isEmpty ? L("Untitled window", "Окно без названия") : window.label
    }
}

@MainActor
private struct WindowLinkSheet: View {
    @ObservedObject var model: AppModel
    let shortcut: Shortcut
    @Environment(\.dismiss) private var dismiss
    @State private var windowID: String?
    @State private var isSaving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("Choose the right window", "Выберите нужное окно"), subtitle: L("Reconnect “\(shortcut.name)” to an open Chrome window.", "Привяжите «\(shortcut.name)» к открытому окну Chrome."))
            Form {
                Section {
                    WindowPicker(model: model, selection: $windowID, shortcutID: shortcut.id)
                } footer: {
                    Text(L("Show the window to check it, then link it here. Your existing Dock icon will keep working.", "Покажите окно для проверки, затем привяжите его здесь. Значок в Dock продолжит работать."))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(isSaving)
            SheetFooter(isBusy: model.isBusy || isSaving, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(isSaving)
                Button(L("Link window", "Привязать окно")) {
                    guard !isSaving, !model.isBusy,
                          let window = model.linkableWindows(for: shortcut.id).first(where: { $0.id == windowID }) else { return }
                    isSaving = true
                    Task {
                        defer { isSaving = false }
                        guard !model.isBusy else { return }
                        await model.relink(shortcut, to: window)
                        if model.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.linkableWindows(for: shortcut.id).contains(where: { $0.id == windowID }) || model.isBusy || isSaving)
            }
        }
        .frame(width: 535, height: 430)
        .interactiveDismissDisabled(isSaving)
    }
}

@MainActor
private struct FaviconSheet: View {
    @ObservedObject var model: AppModel
    let shortcut: Shortcut
    @Environment(\.dismiss) private var dismiss
    @State private var website = ""
    @State private var downloadTask: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("A familiar face from the web", "Знакомый значок сайта"), subtitle: L("Use a website’s icon for “\(shortcut.name)”.", "Поставьте значок сайта на «\(shortcut.name)»."))
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com", text: $website)
                    .textFieldStyle(.roundedBorder)
                Text(L("Use an HTTPS website address. Icons and redirects must stay on that same host; if the icon lives elsewhere, choose an image file.", "Введите HTTPS-адрес сайта. Значок и переадресации должны оставаться на том же домене; если картинка находится на другом сайте, выберите файл."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("The website receives your IP address and the requested address. ProfileDock does not send it your Chrome cookies, account details or window titles. You can choose an image file instead.", "Сайт увидит ваш IP-адрес и запрошенный адрес. ProfileDock не передаёт ему cookies Chrome, данные аккаунтов или заголовки окон. Вместо загрузки можно выбрать файл изображения."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 20)
            SheetFooter(isBusy: model.isBusy, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { downloadTask?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Get icon", "Загрузить значок")) {
                    // Reserve the request before yielding to the main actor so
                    // a second click cannot replace the handle Cancel needs.
                    guard downloadTask == nil, !model.isBusy else { return }
                    downloadTask = Task {
                        defer { downloadTask = nil }
                        let saved = await model.fetchFavicon(for: shortcut, website: website)
                        if saved && !Task.isCancelled { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy || downloadTask != nil)
            }
        }
        .frame(width: 510, height: 345)
        .onDisappear { downloadTask?.cancel() }
    }
}

@MainActor
private struct HelpSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPrivacy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("A Dock that knows your windows", "Dock, который знает ваши окна"), subtitle: L("Three steps to calmer switching.", "Три шага к удобному переключению."))
            VStack(alignment: .leading, spacing: 20) {
                helpStep("1", title: L("Connect Chrome", "Подключите Chrome"), body: L("Allow ProfileDock to control Chrome when macOS asks. Your browsing history is not collected.", "Разрешите ProfileDock управлять Chrome в запросе macOS. История посещений не собирается."))
                helpStep("2", title: L("Check and link a window", "Проверьте и привяжите окно"), body: L("Select a window and click “Show window” to check it in Chrome. Return to setup, give the shortcut a name, and link it. You can add a photo or website icon afterward.", "Выберите окно и нажмите «Показать окно», чтобы проверить его в Chrome. Вернитесь к настройке, назовите ярлык и привяжите окно. Затем можно добавить фотографию или значок сайта."))
                helpStep("3", title: L("Keep its shortcut in the Dock", "Закрепите ярлык в Dock"), body: L("Choose “Create Dock shortcut”, then drag the app from Finder to the Dock. Clicking it brings that window forward.", "Выберите «Создать ярлык для Dock» и перетащите приложение из Finder в Dock. Нажатие поднимет нужное окно."))
                Divider()
                Text(L("If a window is closed or renamed, choose a window again in ProfileDock. With multiple windows for one profile, create a separate shortcut for each.", "Если окно закрыто или переименовано, снова выберите его в ProfileDock. Для нескольких окон одного профиля можно создать отдельные ярлыки."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Button(L("Data and permissions", "Данные и разрешения")) { showingPrivacy = true }
                    Button(L("Privacy settings", "Настройки разрешений")) { model.openPrivacySettings() }
                    Button(L("Open data folder", "Папка данных")) { model.revealDataFolder() }
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            SheetFooter(isBusy: false) {
                Button(L("Got it", "Понятно")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 530)
        .sheet(isPresented: $showingPrivacy) { PrivacySheet(model: model) }
    }
    private func helpStep(_ number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DockStyle.accent)
                .frame(width: 25, height: 25)
                .background(DockStyle.accent.opacity(0.09), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
private struct PrivacySheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("Your data and Chrome access", "Ваши данные и доступ к Chrome"),
                         subtitle: L("ProfileDock does not send your browser data to its developers.", "ProfileDock не отправляет данные браузера разработчикам."))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyRow("macwindow", title: L("What the app reads locally", "Что приложение читает на Mac"),
                        body: L("Profile names, account labels (which may include an email address), profile pictures and normal-window titles help you choose a window. This version skips private-window titles and does not read open page contents, passwords, cookies or browsing history.", "Имена профилей, подписи аккаунтов (в том числе email), фотографии профилей и заголовки обычных окон помогают выбрать окно. Эта версия пропускает заголовки инкогнито и не читает содержимое открытых страниц, пароли, cookies или историю посещений."))
                    privacyRow("externaldrive", title: L("What stays on your Mac", "Что сохраняется на Mac"),
                        body: L("Shortcut names, window bindings and pictures are saved in the app’s data folder and in the shortcuts you create. There is no ProfileDock account, analytics or automatic data upload.", "Имена ярлыков, привязки окон и картинки сохраняются в папке данных и созданных ярлыках. В ProfileDock нет аккаунта, аналитики или автоматической отправки данных."))
                    privacyRow("network", title: L("When the app uses the internet", "Когда нужен интернет"),
                        body: L("Switching windows works without an internet connection. Fetching a website icon is optional: that website receives your IP address and the requested address, without your Chrome cookies or profile data.", "Переключение окон работает без интернета. Загрузка значка сайта — по вашему выбору: сайт получает IP-адрес и запрошенный адрес, без cookies Chrome и данных профилей."))
                    privacyRow("lock.shield", title: L("What the permission means", "Что означает разрешение"),
                        body: L("macOS grants control of Chrome through Automation. There is no separate permission for switching windows only. ProfileDock uses it to find, name and raise windows; the permission is broader than these functions. You can inspect this version’s use in the open source.", "macOS разрешает управление Chrome через Automation. Отдельного разрешения «только переключать окна» нет. ProfileDock использует его для поиска, именования и поднятия окон; разрешение шире этих функций. Работу этой версии можно проверить в открытом коде."))
                    privacyRow("hand.raised", title: L("You can revoke access", "Доступ можно отозвать"),
                        body: L("In System Settings → Privacy & Security → Automation, turn off Google Chrome for ProfileDock. Window switching will stop working. Accessibility, Screen Recording and Full Disk Access are not required.", "В Системных настройках → Конфиденциальность и безопасность → Автоматизация выключите Google Chrome для ProfileDock. Переключение перестанет работать. Универсальный доступ, запись экрана и полный доступ к диску не требуются."))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
            SheetFooter(isBusy: false) {
                Button(L("Permission settings", "Разрешения")) { model.openPrivacySettings() }
                Button(L("Data folder", "Папка данных")) { model.revealDataFolder() }
                Button(L("Done", "Понятно")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 570, height: 620)
    }

    private func privacyRow(_ icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(DockStyle.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SheetHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 21, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
    }
}

private struct SheetFooter<Actions: View>: View {
    let isBusy: Bool
    var errorMessage: String? = nil
    @ViewBuilder var actions: () -> Actions
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            HStack(spacing: 9) {
                if isBusy { ProgressView().controlSize(.small) }
                Spacer()
                actions()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}
