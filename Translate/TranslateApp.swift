import SwiftUI

@main
struct TranslateApp: App {
    @StateObject private var translator = Translator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translator)
                .frame(minWidth: 620, minHeight: 460)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 620)
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
