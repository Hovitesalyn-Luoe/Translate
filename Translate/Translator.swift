import Foundation
import SwiftUI
import Translation
import AVFoundation
import AppKit
import Combine

@MainActor
final class Translator: ObservableObject {

    // MARK: - 输入状态

    @Published var sourceText: String = "" {
        didSet { scheduleAutoTranslate() }
    }

    @Published var translatedText: String = ""
    @Published var sourceLanguageIdentifier: String? = nil   // nil = 自动检测
    @Published var targetLanguageIdentifier: String = "zh-Hans"
    @Published var detectedLanguageIdentifier: String? = nil

    // MARK: - 运行状态

    @Published var configuration: TranslationSession.Configuration?
    @Published var isTranslating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSpeaking = false

    // MARK: - 语言与历史

    @Published var supportedLanguages: [String] = []
    @Published var favorites: [TranslationRecord] = []
    @Published var history: [TranslationRecord] = []

    private var debounceTask: Task<Void, Never>?
    private var lastRequestedText: String = ""
    /// 懒加载：不用朗读的人，永远不创建语音引擎（省下 TTS 常驻内存）
    private lazy var speech = AVSpeechSynthesizer()

    private enum Keys {
        static let history = "translate.history"
        static let favorites = "translate.favorites"
    }

    init() {
        loadStore()
        Task { await loadSupportedLanguages() }
    }

    // MARK: - 语言

    func loadSupportedLanguages() async {
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        var identifiers = Set<String>()
        for language in languages {
            identifiers.insert(language.maximalIdentifier)
        }
        // 保证常用项一定在
        identifiers.formUnion(["zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "ru"])
        supportedLanguages = identifiers.sorted()
    }

    var sourceLanguage: Locale.Language? {
        sourceLanguageIdentifier.map { Locale.Language(identifier: $0) }
    }

    var targetLanguage: Locale.Language {
        Locale.Language(identifier: targetLanguageIdentifier)
    }

    var sourceDisplayName: String {
        guard let identifier = sourceLanguageIdentifier else {
            if let detected = detectedLanguageIdentifier {
                return "自动检测 · \(LanguageCatalog.displayName(for: detected))"
            }
            return "自动检测"
        }
        return LanguageCatalog.displayName(for: identifier)
    }

    var targetDisplayName: String {
        LanguageCatalog.displayName(for: targetLanguageIdentifier)
    }

    // MARK: - 自动翻译

    private func scheduleAutoTranslate() {
        debounceTask?.cancel()
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translatedText = ""
            errorMessage = nil
            return
        }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, !Task.isCancelled else { return }
            self.triggerTranslation()
        }
    }

    func triggerTranslation() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            // 输入清空后别留着上一次的译文或报错
            if !translatedText.isEmpty { translatedText = "" }
            if errorMessage != nil { errorMessage = nil }
            if successMessage != nil { successMessage = nil }
            return
        }

        let source = sourceLanguage
        let target = targetLanguage

        if let current = configuration,
           current.source == source,
           current.target == target {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    func run(_ session: TranslationSession) async {
        let requested = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else { return }

        lastRequestedText = requested
        isTranslating = true
        defer { isTranslating = false }

        do {
            let response = try await session.translate(requested)
            // 用户已经改了文本，丢弃过期结果
            guard lastRequestedText == sourceText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            translatedText = response.targetText
            detectedLanguageIdentifier = response.sourceLanguage.maximalIdentifier
            errorMessage = nil
            successMessage = nil
            recordInHistory(
                source: requested,
                translated: response.targetText,
                sourceLanguage: response.sourceLanguage.maximalIdentifier,
                targetLanguage: response.targetLanguage.maximalIdentifier
            )
        } catch TranslationError.notInstalled {
            errorMessage = "这个语言包还没下载。点一下继续，系统会帮你装。"
            translatedText = ""
        } catch TranslationError.alreadyCancelled {
            // 系统下载面板被关掉时会走到这里，不该算错误
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            translatedText = ""
        }
    }

    // MARK: - 操作

    func swapLanguages() {
        guard let sourceIdentifier = detectedLanguageIdentifier ?? sourceLanguageIdentifier else { return }
        let oldTarget = targetLanguageIdentifier
        let hadTranslation = !translatedText.isEmpty
        sourceLanguageIdentifier = oldTarget
        targetLanguageIdentifier = sourceIdentifier
        if hadTranslation {
            sourceText = translatedText
        } else {
            translatedText = ""
        }
        detectedLanguageIdentifier = nil
        triggerTranslation()
    }

    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedText, forType: .string)
        flash("译文已复制")
    }

    func clear() {
        debounceTask?.cancel()
        sourceText = ""
        translatedText = ""
        errorMessage = nil
        detectedLanguageIdentifier = nil
    }

    // MARK: - 朗读

    func speakSource() {
        speak(sourceText, languageIdentifier: detectedLanguageIdentifier ?? sourceLanguageIdentifier ?? "en")
    }

    func speakTranslation() {
        speak(translatedText, languageIdentifier: targetLanguageIdentifier)
    }

    private func speak(_ text: String, languageIdentifier: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: speechLanguageCode(for: languageIdentifier))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(utterance)
    }

    private func speechLanguageCode(for identifier: String) -> String {
        let upper = identifier.uppercased()
        if upper.hasPrefix("ZH") {
            return upper.contains("TW") || upper.contains("HANT") || upper.contains("HK") ? "zh-TW" : "zh-CN"
        }
        switch identifier {
        case "en": return "en-US"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "ru": return "ru-RU"
        default: return identifier
        }
    }

    // MARK: - 收藏 / 历史

    private func recordInHistory(source: String, translated: String, sourceLanguage: String, targetLanguage: String) {
        if let first = history.first,
           first.sourceText == source,
           first.translatedText == translated,
           first.sourceLanguage == sourceLanguage,
           first.targetLanguage == targetLanguage {
            return
        }

        let record = TranslationRecord(
            sourceText: source,
            translatedText: translated,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        history.insert(record, at: 0)
        if history.count > 120 { history = Array(history.prefix(120)) }
        saveStore()
    }

    var isCurrentFavorite: Bool {
        favorites.contains { record in
            record.sourceText == sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                && record.translatedText == translatedText
        }
    }

    func toggleFavoriteCurrent() {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !translatedText.isEmpty else { return }

        if let index = favorites.firstIndex(where: {
            $0.sourceText == source && $0.translatedText == translatedText
        }) {
            favorites.remove(at: index)
            flash("已取消收藏")
        } else {
            let record = TranslationRecord(
                sourceText: source,
                translatedText: translatedText,
                sourceLanguage: detectedLanguageIdentifier ?? sourceLanguageIdentifier ?? "und",
                targetLanguage: targetLanguageIdentifier
            )
            favorites.insert(record, at: 0)
            flash("已收藏")
        }
        saveStore()
    }

    func load(_ record: TranslationRecord) {
        debounceTask?.cancel()
        sourceLanguageIdentifier = record.sourceLanguage == "und" ? nil : record.sourceLanguage
        targetLanguageIdentifier = record.targetLanguage
        detectedLanguageIdentifier = record.sourceLanguage
        translatedText = record.translatedText
        sourceText = record.sourceText
        debounceTask?.cancel()
    }

    func removeFromHistory(_ record: TranslationRecord) {
        history.removeAll { $0.id == record.id }
        saveStore()
    }

    func removeFromFavorites(_ record: TranslationRecord) {
        favorites.removeAll { $0.id == record.id }
        saveStore()
    }

    private func flash(_ message: String) {
        successMessage = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            if self?.successMessage == message {
                self?.successMessage = nil
            }
        }
    }

    // MARK: - 持久化

    private func loadStore() {
        let defaults = UserDefaults.standard
        history = Self.decode([TranslationRecord].self, from: defaults.data(forKey: Keys.history)) ?? []
        favorites = Self.decode([TranslationRecord].self, from: defaults.data(forKey: Keys.favorites)) ?? []
    }

    private func saveStore() {
        let defaults = UserDefaults.standard
        defaults.set(Self.encode(history), forKey: Keys.history)
        defaults.set(Self.encode(favorites), forKey: Keys.favorites)
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
