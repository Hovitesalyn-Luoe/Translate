import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var translator: Translator
    @Binding var selection: TranslationRecord?

    var body: some View {
        List(selection: $selection) {
            Section {
                if translator.favorites.isEmpty {
                    emptyRow("还没有收藏")
                } else {
                    ForEach(translator.favorites) { record in
                        RecordRow(record: record)
                            .tag(record)
                            .contextMenu {
                                Button("拷贝译文") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(record.translatedText, forType: .string)
                                }
                                Button("从收藏中移除", role: .destructive) {
                                    translator.removeFromFavorites(record)
                                    if selection?.id == record.id { selection = nil }
                                }
                            }
                    }
                }
            } header: {
                Label("收藏", systemImage: "star")
            }

            Section {
                if translator.history.isEmpty {
                    emptyRow("还没有翻译过")
                } else {
                    ForEach(translator.history) { record in
                        RecordRow(record: record)
                            .tag(record)
                            .contextMenu {
                                Button("拷贝译文") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(record.translatedText, forType: .string)
                                }
                                Button("从历史中删除", role: .destructive) {
                                    translator.removeFromHistory(record)
                                    if selection?.id == record.id { selection = nil }
                                }
                            }
                    }
                }
            } header: {
                Label("历史记录", systemImage: "clock")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 2)
    }
}

struct RecordRow: View {
    let record: TranslationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.sourceText.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12.5))
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(record.sourceDisplayName)
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .bold))
                Text(record.targetDisplayName)

                Spacer(minLength: 6)

                Text(Self.timeLabel(record.date))
                    .foregroundStyle(.tertiary)
                    .frame(width: 58, alignment: .trailing)
                    .layoutPriority(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static func timeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return clockFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 " + clockFormatter.string(from: date)
        }
        return dayFormatter.string(from: date)
    }
}
