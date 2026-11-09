import SwiftUI

@main
struct TranslateApp: App {
    @StateObject private var translator = Translator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translator)
                .frame(minWidth: 620, minHeight: 170)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 620)

        Settings {
            SettingsView()
                .environmentObject(translator)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .pasteboard) {
                Button("复制译文") {
                    translator.copyTranslation()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("朗读原文") {
                    translator.speakSource()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandMenu("翻译") {
                Button("翻译") {
                    translator.triggerTranslation()
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("交换语言") {
                    translator.swapLanguages()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("收藏这条翻译") {
                    translator.toggleFavoriteCurrent()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("清空") {
                    translator.clear()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var translator: Translator
    @AppStorage("translate.rememberWindow") private var rememberWindow = true
    @AppStorage("translate.showSidebar") private var rememberSidebar = true

    var body: some View {
        Form {
            Section {
                Picker("目标语言", selection: $translator.targetLanguageIdentifier) {
                    ForEach(translator.supportedLanguages, id: \.self) { identifier in
                        Text(LanguageCatalog.displayName(for: identifier)).tag(identifier)
                    }
                }
                Toggle("边打边翻", isOn: $translator.autoTranslateEnabled)
                Text("关掉之后，输入时不会自动翻译，按 ⌘↵ 手动翻。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("翻译")
            }

            Section {
                Toggle("记住窗口大小和位置", isOn: $rememberWindow)
                Toggle("记住侧边栏开合", isOn: $rememberSidebar)
                Text("关掉之后，下次打开回到默认的窗口大小。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("窗口")
            }

            Section {
                HStack(spacing: 12) {
                    Button("清空历史记录") {
                        translator.clearHistory()
                    }
                    Button("清空收藏") {
                        translator.clearFavorites()
                    }
                }
            } header: {
                Text("数据")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 400)
        .onChange(of: translator.targetLanguageIdentifier) { _, _ in
            translator.triggerTranslation()
        }
    }
}
