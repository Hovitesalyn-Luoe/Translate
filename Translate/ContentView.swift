import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var translator: Translator
    @State private var selectedRecord: TranslationRecord?
    @AppStorage("translate.showSidebar") private var showSidebar = true
    @AppStorage("translate.rememberSidebar") private var rememberSidebar = true
    @AppStorage("translate.rememberWindow") private var rememberWindow = true

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selectedRecord)
                .frame(width: 232)
                .frame(width: showSidebar ? 232 : 0, alignment: .leading)
                .clipped()
                .opacity(showSidebar ? 1 : 0)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: showSidebar ? 1 : 0)
            TranslationView()
        }
        .animation(.smooth(duration: 0.26), value: showSidebar)
        .frame(minWidth: 640, minHeight: 120)
        .background(WindowConfigurator(remember: rememberWindow).frame(width: 0, height: 0))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showSidebar.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                }
                .help(showSidebar ? "隐藏边栏" : "显示边栏")
            }
        }
        .onAppear {
            if !rememberSidebar { showSidebar = true }
        }
        .onChange(of: selectedRecord) { _, newValue in
            guard let record = newValue else { return }
            translator.load(record)
        }
        .translationTask(translator.configuration) { session in
            await translator.run(session)
        }
    }
}

// MARK: - 主翻译界面

struct TranslationView: View {
    @EnvironmentObject private var translator: Translator
    @FocusState private var sourceFocused: Bool
    @State private var didAutoFocus = false
    /// VSplitView 不暴露初始分隔位置，这里等它布局完，直接找底下的 NSSplitView 摆回去
    private func restoreSplitPosition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }),
                  let split = Self.findSplitView(in: window.contentView) else { return }
            // 让 NSSplitView 自己记住分隔位置，比手动记录可靠
            if split.autosaveName == nil {
                split.autosaveName = NSSplitView.AutosaveName("TranslateSplit")
            }
        }
    }

    private static func findSplitView(in view: NSView?) -> NSSplitView? {
        guard let view else { return nil }
        if let split = view as? NSSplitView { return split }
        for sub in view.subviews {
            if let found = findSplitView(in: sub) { return found }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            LanguageBar()
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 9)

            VSplitView {
                SourceArea(focused: $sourceFocused)
                    .frame(minHeight: 40, maxHeight: .infinity)
                TargetArea()
                    .frame(minHeight: 40, maxHeight: .infinity)
            }
            .onAppear(perform: restoreSplitPosition)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .padding(.horizontal, 22)

            Spacer(minLength: 0)

            BottomBar()
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .padding(.top, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // 窗口还没成为 key window 时设 FocusState 不生效，等一拍再聚焦
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sourceFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // 窗口第一次拿到焦点时把光标放进输入框，免得还要手点一下
            guard !didAutoFocus else { return }
            didAutoFocus = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                sourceFocused = true
            }
        }
    }
}

// MARK: - 语言选择条

struct LanguageBar: View {
    @EnvironmentObject private var translator: Translator

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    translator.sourceLanguageIdentifier = nil
                    translator.triggerTranslation()
                } label: {
                    Label("自动检测", systemImage: "wand.and.stars")
                }
                Divider()
                ForEach(translator.supportedLanguages, id: \.self) { identifier in
                    Button(LanguageCatalog.displayName(for: identifier)) {
                        translator.sourceLanguageIdentifier = identifier
                        translator.triggerTranslation()
                    }
                }
            } label: {
                LanguagePill(title: translator.sourceDisplayName, showsChevron: true)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                translator.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("交换语言")

            Menu {
                ForEach(translator.supportedLanguages, id: \.self) { identifier in
                    Button(LanguageCatalog.displayName(for: identifier)) {
                        translator.targetLanguageIdentifier = identifier
                        translator.triggerTranslation()
                    }
                }
            } label: {
                LanguagePill(title: translator.targetDisplayName, showsChevron: true)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            if translator.isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.85)
            }
        }
    }
}

struct LanguagePill: View {
    let title: String
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.055))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.07))
        )
        .contentShape(Capsule())
    }
}

// MARK: - 原文输入

struct SourceArea: View {
    @EnvironmentObject private var translator: Translator
    var focused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $translator.sourceText)
                .font(.system(size: 21, weight: .regular))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused(focused)
                .padding(.horizontal, 11)
                .padding(.vertical, 12)

        }
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if !translator.sourceText.isEmpty {
                Text("\(translator.sourceText.count) 字")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - 译文输出

struct TargetArea: View {
    @EnvironmentObject private var translator: Translator

    var body: some View {
        ZStack(alignment: .leading) {
            if translator.translatedText.isEmpty {
                Text(translator.errorMessage ?? "译文会出现在这里")
                    .font(.system(size: 21))
                    .foregroundStyle(translator.errorMessage == nil ? Color.secondary : Color.orange)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(translator.translatedText)
                            .font(.system(size: 21, weight: .regular))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.06))
    }
}

// MARK: - 底部工具条

struct BottomBar: View {
    @EnvironmentObject private var translator: Translator

    var body: some View {
        HStack(spacing: 4) {
            ToolButton(icon: "speaker.wave.2", help: "朗读原文") {
                translator.speakSource()
            }
            .disabled(translator.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            ToolButton(icon: "speaker.wave.3", help: "朗读译文") {
                translator.speakTranslation()
            }
            .disabled(translator.translatedText.isEmpty)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 6)

            ToolButton(
                icon: translator.isCurrentFavorite ? "star.fill" : "star",
                help: "收藏"
            ) {
                translator.toggleFavoriteCurrent()
            }
            .disabled(translator.translatedText.isEmpty)

            ToolButton(icon: "doc.on.doc", help: "复制译文") {
                translator.copyTranslation()
            }
            .disabled(translator.translatedText.isEmpty)

            Spacer()

            if let message = translator.successMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            ToolButton(icon: "xmark.circle", help: "清空") {
                translator.clear()
            }
            .disabled(translator.sourceText.isEmpty && translator.translatedText.isEmpty)
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: translator.successMessage)
    }
}

struct ToolButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering ? Color.primary.opacity(0.07) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// 拿到底层 NSWindow，交给 AppKit 自己记 frame / 位置
struct WindowConfigurator: NSViewRepresentable {
    var remember: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let name = NSWindow.FrameAutosaveName("TranslateMainWindow")
            if remember {
                _ = window.setFrameUsingName(name)
                window.setFrameAutosaveName(name)
            } else {
                window.setFrameAutosaveName("")
                UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(name)")
                let screen = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let size = NSSize(width: 780, height: 620)
                let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
                window.setFrame(NSRect(origin: origin, size: size), display: true)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
