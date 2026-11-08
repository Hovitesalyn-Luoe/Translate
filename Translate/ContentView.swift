import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var translator: Translator
    @State private var selectedRecord: TranslationRecord?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedRecord)
                .navigationSplitViewColumnWidth(min: 200, ideal: 235, max: 320)
        } detail: {
            TranslationView()
        }
        .navigationSplitViewStyle(.balanced)
        // 侧边栏收起/展开时不要给整窗做隐式动画，否则正文会闪一下
        .transaction(value: columnVisibility) { transaction in
            transaction.disablesAnimations = true
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

    var body: some View {
        VStack(spacing: 0) {
            LanguageBar()
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 14)

            VStack(spacing: 12) {
                SourceArea(focused: $sourceFocused)
                TargetArea()
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 0)

            BottomBar()
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
                .padding(.top, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // 窗口还没成为 key window 时设 FocusState 不生效，等一拍再聚焦
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            if translator.sourceText.isEmpty {
                // 和 TextEditor 里文字的实际起点对齐：14 容器边距 + 5 文本容器内边距
                Text("输入或粘贴要翻译的文字")
                    .font(.system(size: 21))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 17)
                    .padding(.top, 7)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if translator.translatedText.isEmpty {
                    Text(translator.errorMessage ?? "译文会出现在这里")
                        .font(.system(size: 21))
                        .foregroundStyle(translator.errorMessage == nil ? Color.secondary : Color.orange)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    Text(translator.translatedText)
                        .font(.system(size: 21, weight: .regular))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 140, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.12))
        )
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
