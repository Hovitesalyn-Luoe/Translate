import Foundation

struct TranslationRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var sourceText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var date: Date = Date()

    var sourceDisplayName: String { LanguageCatalog.displayName(for: sourceLanguage) }
    var targetDisplayName: String { LanguageCatalog.displayName(for: targetLanguage) }
}

enum LanguageCatalog {
    private static let zhLocale = Locale(identifier: "zh_CN")

    /// 中文界面里用的短名字，避免「英语（拉丁文，美国）」这种又长又拗口的全名。
    private static let shortNames: [String: String] = [
        "en": "英语",
        "ja": "日语",
        "ko": "韩语",
        "fr": "法语",
        "de": "德语",
        "es": "西班牙语",
        "it": "意大利语",
        "pt": "葡萄牙语",
        "ru": "俄语",
        "ar": "阿拉伯语",
        "th": "泰语",
        "vi": "越南语",
        "id": "印尼语",
        "ms": "马来语",
        "hi": "印地语",
        "tr": "土耳其语",
        "pl": "波兰语",
        "nl": "荷兰语",
        "uk": "乌克兰语",
        "sv": "瑞典语",
        "da": "丹麦语",
        "nb": "挪威语",
        "no": "挪威语",
        "fi": "芬兰语",
        "cs": "捷克语",
        "el": "希腊语",
        "he": "希伯来语",
        "hu": "匈牙利语",
        "ro": "罗马尼亚语",
        "sk": "斯洛伐克语",
        "bg": "保加利亚语",
        "hr": "克罗地亚语",
        "ca": "加泰罗尼亚语",
        "tl": "菲律宾语",
        "fa": "波斯语",
        "ur": "乌尔都语",
        "bn": "孟加拉语",
        "ta": "泰米尔语",
        "te": "泰卢固语",
        "mr": "马拉地语",
        "gu": "古吉拉特语",
        "kn": "卡纳达语",
        "ml": "马拉雅拉姆语",
        "pa": "旁遮普语",
        "sw": "斯瓦希里语",
        "af": "南非荷兰语",
        "sq": "阿尔巴尼亚语",
        "hy": "亚美尼亚语",
        "az": "阿塞拜疆语",
        "be": "白俄罗斯语",
        "bs": "波斯尼亚语",
        "et": "爱沙尼亚语",
        "eu": "巴斯克语",
        "fil": "菲律宾语",
        "ga": "爱尔兰语",
        "gl": "加利西亚语",
        "is": "冰岛语",
        "ka": "格鲁吉亚语",
        "kk": "哈萨克语",
        "km": "高棉语",
        "lo": "老挝语",
        "lt": "立陶宛语",
        "lv": "拉脱维亚语",
        "mk": "马其顿语",
        "mn": "蒙古语",
        "my": "缅甸语",
        "ne": "尼泊尔语",
        "si": "僧伽罗语",
        "sl": "斯洛文尼亚语",
        "sr": "塞尔维亚语",
        "uz": "乌兹别克语",
        "yo": "约鲁巴语",
        "zu": "祖鲁语"
    ]

    static func displayName(for identifier: String) -> String {
        if identifier.isEmpty { return "未知语言" }

        let lower = identifier.lowercased()
        if lower.hasPrefix("zh") {
            let traditional = lower.contains("hant") || lower.contains("tw")
                || lower.contains("hk") || lower.contains("mo")
            return traditional ? "繁体中文" : "简体中文"
        }

        let base = lower.split(separator: "-").first.map(String.init) ?? lower
        if let name = shortNames[base] { return name }

        if let name = zhLocale.localizedString(forIdentifier: identifier) {
            // 兜底：把「（拉丁文，美国）」这种尾巴削掉
            let cleaned = name.replacingOccurrences(of: "（拉丁文，", with: "（")
            return cleaned
        }
        return identifier
    }

    static func shortCode(for identifier: String) -> String {
        let upper = identifier.uppercased()
        if upper.hasPrefix("ZH") {
            return upper.contains("TW") || upper.contains("HANT") || upper.contains("HK") ? "繁" : "简"
        }
        let parts = identifier.split(separator: "-")
        return parts.first.map(String.init) ?? identifier
    }
}
