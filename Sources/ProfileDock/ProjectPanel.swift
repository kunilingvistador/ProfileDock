import AppKit
import SwiftUI
import ProfileDockCore

enum ProjectSection: String, CaseIterable, Identifiable {
    case status, support, feedback, data
    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: return L("Status", "Состояние")
        case .support: return L("Support", "Поддержать")
        case .feedback: return L("Feedback", "Отзывы")
        case .data: return L("Privacy", "Приватность")
        }
    }
    var symbol: String {
        switch self {
        case .status: return "checkmark.shield"
        case .support: return "heart"
        case .feedback: return "bubble.left.and.bubble.right"
        case .data: return "hand.raised"
        }
    }
}

/// Glass belongs to the controls layer; content retains an opaque, legible surface.
struct DockGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !reduceTransparency, !CommandLine.arguments.contains("--demo-no-glass") {
            content.glassEffect(.regular, in: Capsule())
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }
    private func fallback(_ content: Content) -> some View {
        content.background(Color(nsColor: .controlBackgroundColor), in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.10)))
    }
}

struct DockPrimaryButton: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !CommandLine.arguments.contains("--demo-no-glass") { content.buttonStyle(.glassProminent) }
        else { content.buttonStyle(.borderedProminent) }
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}

@MainActor
struct ProjectPanel: View {
    @ObservedObject var model: AppModel
    @State var selection: ProjectSection
    let onRelink: (Shortcut) -> Void
    let onPrivacy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackKind = 0
    @State private var message = ""
    @State private var includeDiagnostics = false
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var availableSections: [ProjectSection] {
        model.showsSupportPrototype ? ProjectSection.allCases : [.status, .feedback, .data]
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("Unknown", "Неизвестна")
    }
    private var readyCount: Int { model.shortcuts.filter { model.status(for: $0) == .ready }.count }
    private var needsAttention: [Shortcut] {
        model.shortcuts.filter { [.missing, .ambiguous].contains(model.status(for: $0)) }
    }
    private var connectionReady: Bool { model.chromeRunning && model.permissionGranted && model.hasWindowSnapshot }
    private var healthy: Bool { connectionReady && needsAttention.isEmpty && model.hotKeyFailures.isEmpty && model.hotKeyStorageError == nil }
    private var diagnosticText: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        // Explicit allowlist. No profile, account, window title, shortcut UUID,
        // local path, URL, clipboard content or error detail is included.
        return "ProfileDock: \(version)\nmacOS: \(os.majorVersion).\(os.minorVersion)\nPreview: \(model.demoMode ? "yes" : "no")\nChrome running: \(model.chromeRunning ? "yes" : "no")\nWindow snapshot available: \(model.hasWindowSnapshot ? "yes" : "no")\nHotkeys enabled: \(model.hotKeyDocument.enabled ? "yes" : "no")"
    }
    private var feedbackText: String {
        let kinds = [L("Problem", "Проблема"), L("Idea", "Идея"), L("Thanks", "Спасибо")]
        var text = "ProfileDock — \(kinds[feedbackKind])\n\n\(message.trimmingCharacters(in: .whitespacesAndNewlines))"
        if includeDiagnostics { text += "\n\n" + diagnosticText }
        return text
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selection.title).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain).modifier(DockGlass())
                    .help(L("Close", "Закрыть"))
                    .accessibilityLabel(L("Close project panel", "Закрыть панель проекта"))
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 18)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selection {
                        case .status: statusContent
                        case .support: supportContent
                        case .feedback: feedbackContent
                        case .data: dataContent
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26).padding(.bottom, 28)
                }
                .id(selection)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 760, height: 570)
        .tint(.accentColor)
        .onAppear {
            if !availableSections.contains(selection) { selection = .status }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 9) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.accentColor)
                Text("ProfileDock").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(.top, 7)
            VStack(spacing: 5) {
                ForEach(availableSections) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                            .font(.system(size: 13, weight: selection == section ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11).padding(.vertical, 11)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                            .background(selection == section ? Color.accentColor.opacity(0.10) : .clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == section ? Color.accentColor : Color.primary)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                Label(L("Works locally", "Работает локально"), systemImage: "lock.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Text(model.demoMode ? L("Local preview", "Локальный предпросмотр") : version)
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .padding(18).frame(width: 178)
        .frame(maxHeight: .infinity)
        .background(.bar)
    }

    private func heading(_ title: String, _ subtitle: String, symbol: String, color: Color = .accentColor) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 21, weight: .medium))
                    .foregroundStyle(color).accessibilityHidden(true)
                Text(title).font(.system(size: 20, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            }
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(healthy ? L("Everything is ready", "Всё готово к работе") : L("Connection status", "Состояние подключения"),
                    L("Connections, windows and keyboard shortcuts.", "Подключение, окна и сочетания клавиш."),
                    symbol: "checkmark.shield", color: healthy ? .green : .orange)
            VStack(spacing: 0) {
                statusRow("globe", title: "Google Chrome", detail: connectionReady
                    ? L("Connected · window list received", "Подключён · список окон получен")
                    : L("Connection needs checking", "Нужно проверить подключение"), good: connectionReady)
                Divider().padding(.leading, 44)
                statusRow("macwindow.on.rectangle", title: L("Linked windows", "Привязанные окна"), detail: model.hasWindowSnapshot
                    ? L("\(readyCount) of \(model.shortcuts.count) ready to switch", "Готовы к переключению: \(readyCount) из \(model.shortcuts.count)")
                    : L("Refresh the window list to check", "Обновите список окон для проверки"), good: model.hasWindowSnapshot && needsAttention.isEmpty)
                Divider().padding(.leading, 44)
                statusRow("keyboard", title: L("Hotkeys", "Сочетания клавиш"), detail: !model.hotKeyDocument.enabled
                    ? L("Paused · assignments are saved", "Приостановлены · назначения сохранены")
                    : model.hotKeyFailures.isEmpty && model.hotKeyStorageError == nil
                        ? L("\(model.hotKeyDocument.assignments.count) assigned", "Назначено: \(model.hotKeyDocument.assignments.count)")
                        : L("Some combinations need attention", "Некоторые сочетания требуют проверки"), good: model.hotKeyDocument.enabled && model.hotKeyFailures.isEmpty && model.hotKeyStorageError == nil)
            }
            .padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            ForEach(needsAttention) { shortcut in
                VStack(alignment: .leading, spacing: 9) {
                    Label(shortcut.name, systemImage: "link.badge.plus").font(.system(size: 13, weight: .semibold))
                    Text(model.status(for: shortcut) == .ambiguous
                         ? L("Several windows match. Choose the one to bring forward.", "Совпало несколько окон. Выберите то, которое нужно поднимать.")
                         : L("The window may be closed or renamed. Open it in Chrome and reconnect this shortcut.", "Окно могло закрыться или сменить имя. Откройте его в Chrome и заново привяжите ярлык."))
                        .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(L("Choose window", "Выбрать окно")) { onRelink(shortcut) }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(Color.orange.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
            }
            if let error = model.hotKeyStorageError {
                Label(error, systemImage: "keyboard.badge.ellipsis")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if !model.hotKeyFailures.isEmpty {
                Label(L("Open the keyboard button on a shortcut to change a conflicting combination.", "Откройте кнопку сочетания на ярлыке, чтобы заменить занятую комбинацию."), systemImage: "keyboard.badge.ellipsis")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(L("Refresh status", "Обновить состояние")) { Task { await model.refresh() } }
                    .disabled(model.demoMode || model.isBusy)
                Spacer()
                Button(L("Permission details", "О разрешениях")) { onPrivacy() }.buttonStyle(.link)
            }
            if model.demoMode {
                Text(L("Sample status. Your Chrome windows are not checked or changed.", "Пример состояния. Ваши окна Chrome не проверяются и не изменяются."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func statusRow(_ symbol: String, title: String, detail: String, good: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: good ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(good ? Color.green : Color.orange)
                .accessibilityLabel(good ? L("Ready", "Готово") : L("Check", "Проверить"))
        }.padding(.vertical, 11)
    }

    private var supportContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading(L("Support ProfileDock", "Поддержать ProfileDock"),
                    L("If ProfileDock makes your day easier, you can help it grow.", "Если ProfileDock делает ваш день удобнее, можно помочь ему развиваться."), symbol: "heart", color: .pink)
            VStack(alignment: .leading, spacing: 15) {
                Label(L("Always free to use", "Все возможности бесплатны"), systemImage: "gift")
                Label(L("Support is entirely optional", "Поддержка — только по желанию"), systemImage: "heart")
                Label(L("Helps with testing and future updates", "Помогает с тестами и обновлениями"), systemImage: "wrench.and.screwdriver")
            }
            .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 9) {
                Button {} label: {
                    Label(L("Support ProfileDock", "Поддержать ProfileDock"), systemImage: "heart.fill")
                        .padding(.horizontal, 15).padding(.vertical, 7)
                }.modifier(DockPrimaryButton()).disabled(true)
                Text(L("Payments are not connected in this preview. We’ll choose a payment service before release.", "Оплата пока не подключена. Перед выпуском выберем удобный способ поддержки."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text(L("You can help in other ways, too.", "Можно помочь и без доната."))
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 16) {
                Button(L("Share an idea", "Предложить идею")) { selection = .feedback; feedbackKind = 1 }
                Button(L("View GitHub", "Открыть GitHub")) {
                    NSWorkspace.shared.open(URL(string: "https://github.com/kunilingvistador/ProfileDock")!)
                }
            }.buttonStyle(.link).font(.system(size: 12))
        }
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading(L("Send feedback", "Написать отзыв"),
                    L("Tell us what got in your way, or what you’d like to see.", "Расскажите, что мешает или чего не хватает."), symbol: "bubble.left.and.bubble.right")
            Picker(L("Feedback type", "Тип отзыва"), selection: $feedbackKind) {
                Text(L("Problem", "Проблема")).tag(0)
                Text(L("Idea", "Идея")).tag(1)
                Text(L("Thanks", "Спасибо")).tag(2)
            }.pickerStyle(.segmented)
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(feedbackKind == 0
                         ? L("What did you expect, and what happened instead?", "Что вы ожидали и что произошло на самом деле?")
                         : feedbackKind == 1
                            ? L("What would make ProfileDock more useful for you?", "Что сделает ProfileDock полезнее для вас?")
                            : L("What did you find helpful?", "Расскажите, что оказалось полезным."))
                        .font(.system(size: 12)).foregroundStyle(.tertiary).padding(10).allowsHitTesting(false)
                }
                TextEditor(text: $message).font(.system(size: 13)).scrollContentBackground(.hidden).padding(5)
                    .accessibilityLabel(L("Your feedback", "Ваш отзыв"))
            }
            .frame(height: 115).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.10)))
            Toggle(L("Include a basic technical summary", "Приложить техническую справку"), isOn: $includeDiagnostics)
                .font(.system(size: 12))
            if includeDiagnostics {
                Text(diagnosticText).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }
            Text(L("Review your text before sharing. Avoid account names, window titles and other private details. Nothing is sent automatically.", "Проверьте текст перед отправкой: не добавляйте аккаунты, заголовки окон и личные данные. Автоматически ничего не отправляется."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(feedbackText, forType: .string)
                    copied = true
                } label: {
                    Label(copied ? L("Copied", "Скопировано") : L("Copy feedback", "Скопировать отзыв"), systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .modifier(DockPrimaryButton()).disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: copied)
                Button(L("Open GitHub Issues ↗", "Открыть GitHub Issues ↗")) {
                    NSWorkspace.shared.open(URL(string: "https://github.com/kunilingvistador/ProfileDock/issues")!)
                }.buttonStyle(.link)
            }
            Text(L("Paste the copied message into a GitHub issue. Posting requires a GitHub account; you can review and edit the text before publishing.", "Вставьте скопированный текст в обращение на GitHub. Для публикации нужен аккаунт; перед отправкой текст можно проверить и изменить."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: message) { _ in copied = false }
        .onChange(of: feedbackKind) { _ in copied = false }
        .onChange(of: includeDiagnostics) { _ in copied = false }
    }

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(L("Your data", "Ваши данные"),
                    L("Window switching stays local. You choose what to share.", "Переключение работает локально. Вы решаете, чем делиться."), symbol: "hand.raised")
            VStack(alignment: .leading, spacing: 12) {
                Label(L("No account or app analytics", "Без аккаунта и аналитики приложения"), systemImage: "lock.shield")
                    .font(.system(size: 13, weight: .semibold))
                Text(L("ProfileDock does not send usage events, installation identifiers or browser data to its developers. Shortcut names, window bindings, pictures and hotkeys are stored on this Mac.", "ProfileDock не отправляет разработчикам события использования, идентификаторы установки или данные браузера. Имена ярлыков, привязки окон, картинки и сочетания клавиш хранятся на этом Mac."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 12) {
                Text(L("When you choose to share", "Когда вы сами делитесь данными"))
                    .font(.system(size: 14, weight: .semibold))
                Label(L("Fetching a website icon connects directly to that website, without Chrome cookies or profile data.", "Загрузка значка сайта обращается к самому сайту, без cookies Chrome и данных профилей."), systemImage: "globe")
                Label(L("Opening GitHub uses your browser. No feedback text or diagnostic summary is sent automatically.", "GitHub открывается в браузере. Текст отзыва и техническая справка автоматически не отправляются."), systemImage: "bubble.left")
                Label(L("You can inspect the optional technical summary before copying it with your feedback.", "Необязательную техническую справку можно проверить перед копированием вместе с отзывом."), systemImage: "doc.text.magnifyingglass")
            }
            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Text(L("macOS Automation access lets ProfileDock find, name and raise Chrome windows. The permission is broader than window switching; you can inspect its use in the open source.", "Разрешение macOS «Автоматизация» позволяет ProfileDock находить, именовать и поднимать окна Chrome. Само разрешение шире переключения окон; его использование можно проверить в открытом коде."))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("What Chrome access means", "Что означает доступ к Chrome")) { onPrivacy() }.buttonStyle(.link)
        }
    }
}
