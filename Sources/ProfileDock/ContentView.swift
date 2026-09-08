import AppKit
import SwiftUI
import ProfileDockCore

private enum DockStyle {
    static let accent = Color.indigo
    static let border = Color.primary.opacity(0.07)
    static let muted = Color.secondary
}

private enum EditorRoute: Identifiable {
    case create, edit(Shortcut), relink(Shortcut), favicon(Shortcut), help
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let shortcut): return "edit-\(shortcut.id)"
        case .relink(let shortcut): return "relink-\(shortcut.id)"
        case .favicon(let shortcut): return "favicon-\(shortcut.id)"
        case .help: return "help"
        }
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var route: EditorRoute?

    private var filteredShortcuts: [Shortcut] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? model.shortcuts : model.shortcuts.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                if let notice = model.notice, !notice.isEmpty {
                    noticeBanner(notice)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                }
                if model.shortcuts.isEmpty {
                    onboarding
                } else {
                    library
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(DockStyle.accent)
        .frame(minWidth: 800, minHeight: 560)
        .sheet(item: $route) { selectedRoute in
            switch selectedRoute {
            case .create:
                ShortcutEditor(model: model, shortcut: nil)
            case .edit(let shortcut):
                ShortcutEditor(model: model, shortcut: shortcut)
            case .relink(let shortcut):
                WindowLinkSheet(model: model, shortcut: shortcut)
            case .favicon(let shortcut):
                FaviconSheet(model: model, shortcut: shortcut)
            case .help:
                HelpSheet(model: model)
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                BrandMark(size: 34)
                Text("ProfileDock")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .padding(.top, 7)

            VStack(alignment: .leading, spacing: 9) {
                Text(L("YOUR SPACE", "ВАШЕ ПРОСТРАНСТВО"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)
                    .padding(.horizontal, 10)
                HStack(spacing: 9) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13))
                    Text(L("Shortcuts", "Ярлыки"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 4)
                    Text("\(model.shortcuts.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DockStyle.accent.opacity(0.10), in: Capsule())
                }
                .foregroundStyle(DockStyle.accent)
                .padding(10)
                .background(DockStyle.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.chromeRunning && model.permissionGranted ? Color.green : Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(connectionLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Divider()
                Button { route = .help } label: {
                    Label(L("How it works", "Как это работает"), systemImage: "questionmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Text(L("A little less switching around.", "Каждому окну — своё место."))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 183)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var connectionLabel: String {
        if !model.chromeRunning { return L("Chrome is not running", "Chrome закрыт") }
        if !model.permissionGranted { return L("Connect to Chrome", "Нужно подключить Chrome") }
        return L("Chrome connected", "Chrome подключён")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Your windows, one click away.", "Ваши окна. Один клик."))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(L("A personal Dock shortcut for each Chrome window.", "Отдельный значок в Dock для каждого окна Chrome."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Menu {
                    Button(L("Import existing shortcuts…", "Импортировать готовые ярлыки…")) { model.importExisting() }
                    Button(L("Create all Dock shortcuts", "Создать все ярлыки для Dock")) { model.exportAll() }
                        .disabled(model.shortcuts.isEmpty)
                    Divider()
                    Button(L("Privacy settings", "Настройки разрешений")) { model.openPrivacySettings() }
                    Button(L("Open data folder", "Открыть папку данных")) { model.revealDataFolder() }
                    Divider()
                    Button(L("How it works", "Как это работает")) { route = .help }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L("More options", "Дополнительные действия"))
            }

            if !model.shortcuts.isEmpty {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(L("Find a shortcut", "Найти ярлык"), text: $search)
                            .textFieldStyle(.plain)
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help(L("Clear search", "Очистить поиск"))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DockStyle.border))

                    Button { Task { await model.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 17, height: 19)
                    }
                    .disabled(model.isBusy)
                    .keyboardShortcut("r", modifiers: .command)
                    .help(L("Refresh windows", "Обновить список окон"))

                    Button { route = .create } label: {
                        Label(L("Add", "Добавить"), systemImage: "plus")
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .padding(28)
    }

    private func noticeBanner(_ notice: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill").foregroundStyle(DockStyle.accent)
            Text(notice)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button { model.notice = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L("Dismiss", "Скрыть"))
        }
        .padding(12)
        .background(DockStyle.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var onboarding: some View {
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
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
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
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
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
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 25)).foregroundStyle(.tertiary)
                    Text(L("No matching shortcuts", "Ничего не нашлось"))
                        .font(.headline)
                    Button(L("Clear search", "Очистить поиск")) { search = "" }
                        .buttonStyle(.link)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 11) {
                        ForEach(filteredShortcuts) { shortcut in
                            shortcutCard(shortcut)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 1)
                    .padding(.bottom, 20)
                }
            }

            HStack(spacing: 7) {
                if model.isBusy { ProgressView().controlSize(.mini) }
                Text(model.isBusy ? L("Updating…", "Обновляем…") : L("Only the window you choose comes forward.", "Наверх поднимается только выбранное окно."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if !model.isBusy {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
    }

    private func shortcutCard(_ shortcut: Shortcut) -> some View {
        let status = model.status(for: shortcut)
        return VStack(spacing: 0) {
            HStack(spacing: 13) {
                ShortcutAvatar(image: model.icon(for: shortcut), name: shortcut.name, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(shortcut.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .help(shortcut.name)
                    StatusBadge(status: status)
                }
                Spacer(minLength: 4)
                if status == .ready {
                    Button { Task { await model.switchTo(shortcut) } } label: {
                        Label(L("Switch", "Переключить"), systemImage: "arrow.up.forward")
                    }
                    .disabled(model.isBusy)
                    .help(L("Bring this window to the front", "Поднять это окно наверх"))
                } else if status == .missing || status == .ambiguous {
                    Button(L("Choose window", "Выбрать окно")) { route = .relink(shortcut) }
                        .disabled(model.isBusy)
                }
                Menu {
                    Button(L("Edit shortcut…", "Настроить ярлык…")) { route = .edit(shortcut) }
                    Button(L("Choose another window…", "Привязать другое окно…")) { route = .relink(shortcut) }
                    Divider()
                    Button(L("Choose picture…", "Выбрать изображение…")) { model.chooseImage(for: shortcut) }
                    Button(L("Use a website icon…", "Взять значок сайта…")) { route = .favicon(shortcut) }
                    Divider()
                    Button(L("Create Dock shortcut", "Создать ярлык для Dock")) { model.exportShortcut(shortcut) }
                    Divider()
                    Button(L("Remove shortcut", "Удалить ярлык"), role: .destructive) { model.removeShortcut(shortcut) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 22, height: 24)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L("Shortcut options", "Действия с ярлыком"))
            }
            .padding(16)

            if model.selectedShortcutID == shortcut.id {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 15) {
                    Button { route = .edit(shortcut) } label: {
                        Label(L("Customize", "Настроить"), systemImage: "slider.horizontal.3")
                    }
                    Button { model.exportShortcut(shortcut) } label: {
                        Label(L("Create Dock shortcut", "Создать ярлык для Dock"), systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(DockStyle.accent)
                .padding(.horizontal, 17)
                .padding(.vertical, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(model.selectedShortcutID == shortcut.id ? DockStyle.accent.opacity(0.35) : DockStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .onTapGesture { model.selectedShortcutID = shortcut.id }
        .onTapGesture(count: 2) { if status == .ready { Task { await model.switchTo(shortcut) } } }
    }
}

private struct BrandMark: View {
    var size: CGFloat
    var body: some View {
        Image(systemName: "macwindow.on.rectangle")
            .font(.system(size: size * 0.49, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color.indigo, Color.indigo.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.27))
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

private struct StatusBadge: View {
    let status: ShortcutStatus
    private var color: Color {
        switch status {
        case .ready: return .green
        case .missing, .ambiguous: return .orange
        case .disconnected, .checking: return .secondary
        }
    }
    private var label: String {
        switch status {
        case .ready: return L("Window ready", "Окно готово")
        case .missing: return L("Window not found", "Окно не найдено")
        case .ambiguous: return L("Several windows match", "Найдено несколько окон")
        case .disconnected: return L("Waiting for Chrome", "Нет связи с Chrome")
        case .checking: return L("Checking…", "Проверяем…")
        }
    }
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
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

    init(model: AppModel, shortcut: Shortcut?) {
        self.model = model
        self.shortcut = shortcut
        _name = State(initialValue: shortcut?.name ?? "")
        _profileID = State(initialValue: shortcut?.profileDirectory)
    }

    private var profile: BrowserProfile? { model.profiles.first { $0.id == profileID } }
    private var selectedWindow: BrowserWindow? { model.linkableWindows().first { $0.id == windowID } }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (shortcut != nil || selectedWindow != nil) && !model.isBusy
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
                    TextField(L("Shortcut name", "Название ярлыка"), text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if isValid { save() } }
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

            SheetFooter(isBusy: model.isBusy, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(shortcut == nil ? L("Create shortcut", "Создать ярлык") : L("Save", "Сохранить")) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .frame(width: 555, height: shortcut == nil ? 595 : 440)
        .sheet(isPresented: $showingFavicon) {
            if let shortcut { FaviconSheet(model: model, shortcut: shortcut) }
        }
    }

    private func save() {
        Task {
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
            SheetFooter(isBusy: model.isBusy, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Link window", "Привязать окно")) {
                    guard let window = model.linkableWindows(for: shortcut.id).first(where: { $0.id == windowID }) else { return }
                    Task {
                        await model.relink(shortcut, to: window)
                        if model.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.linkableWindows(for: shortcut.id).contains(where: { $0.id == windowID }) || model.isBusy)
            }
        }
        .frame(width: 535, height: 430)
    }
}

@MainActor
private struct FaviconSheet: View {
    @ObservedObject var model: AppModel
    let shortcut: Shortcut
    @Environment(\.dismiss) private var dismiss
    @State private var website = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("A familiar face from the web", "Знакомый значок сайта"), subtitle: L("Use a website’s icon for “\(shortcut.name)”.", "Поставьте значок сайта на «\(shortcut.name)»."))
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com", text: $website)
                    .textFieldStyle(.roundedBorder)
                Text(L("ProfileDock visits this address to download its public website icon.", "ProfileDock обратится по этому адресу и скачает общедоступный значок сайта."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 20)
            SheetFooter(isBusy: model.isBusy, errorMessage: model.errorMessage) {
                Button(L("Cancel", "Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Get icon", "Загрузить значок")) {
                    Task {
                        await model.fetchFavicon(for: shortcut, website: website)
                        if model.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .frame(width: 470, height: 255)
    }
}

@MainActor
private struct HelpSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: L("A Dock that knows your windows", "Dock, который знает ваши окна"), subtitle: L("Three steps to calmer switching.", "Три шага к удобному переключению."))
            VStack(alignment: .leading, spacing: 20) {
                helpStep("1", title: L("Connect Chrome", "Подключите Chrome"), body: L("Allow ProfileDock to control Chrome when macOS asks. Your browsing history is not collected.", "Разрешите ProfileDock управлять Chrome в запросе macOS. История посещений не собирается."))
                helpStep("2", title: L("Name and link a window", "Назовите и привяжите окно"), body: L("Select the window you want. Add a recognizable photo, profile avatar, or website icon.", "Выберите нужное окно. Добавьте фотографию, аватар профиля или значок сайта."))
                helpStep("3", title: L("Keep its shortcut in the Dock", "Закрепите ярлык в Dock"), body: L("Choose “Create Dock shortcut”, then drag the app from Finder to the Dock. Clicking it brings that window forward.", "Выберите «Создать ярлык для Dock» и перетащите приложение из Finder в Dock. Нажатие поднимет нужное окно."))
                Divider()
                Text(L("If a window is closed or renamed, choose a window again in ProfileDock. With multiple windows for one profile, create a separate shortcut for each.", "Если окно закрыто или переименовано, снова выберите его в ProfileDock. Для нескольких окон одного профиля можно создать отдельные ярлыки."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
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
