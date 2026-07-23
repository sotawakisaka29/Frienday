//
//  FriendayWidget.swift
//  FriendayWidget
//
//  Created by 脇坂颯大 on 23/07/2026.
//

import SwiftUI
import UIKit
import WidgetKit

/// 誕生日ウィジェットへ日ごとの表示内容を渡します。
struct BirthdayProvider: TimelineProvider {
    /// ウィジェットギャラリー用の表示例を返します。
    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: Date(), people: WidgetBirthdayPerson.samples, hasLoadedData: true)
    }

    /// ギャラリーまたは現在時刻のスナップショットを返します。
    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }

        completion(makeEntry(for: Date(), allPeople: WidgetBirthdayStore().load()))
    }

    /// 今日から8日分の誕生日表示を、毎日0時に切り替える予定として返します。
    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let allPeople = WidgetBirthdayStore().load()
        var entries = [makeEntry(for: now, allPeople: allPeople)]

        for dayOffset in 1 ..< 8 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
                continue
            }
            entries.append(makeEntry(for: date, allPeople: allPeople))
        }

        let nextReload = calendar.date(byAdding: .day, value: 8, to: startOfToday)
        let policy = nextReload.map(TimelineReloadPolicy.after) ?? .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    /// 指定した日の誕生日だけを取り出してエントリーを作ります。
    private func makeEntry(for date: Date, allPeople: [WidgetBirthdayPerson]?) -> BirthdayEntry {
        guard let allPeople else {
            return BirthdayEntry(date: date, people: [], hasLoadedData: false)
        }

        let people = allPeople.filter { $0.hasBirthday(on: date) }
        return BirthdayEntry(date: date, people: people, hasLoadedData: true)
    }
}

/// ウィジェットが指定時刻に表示する誕生日情報です。
struct BirthdayEntry: TimelineEntry {
    let date: Date
    let people: [WidgetBirthdayPerson]
    let hasLoadedData: Bool
}

/// App Groupから読み込む、ウィジェット用の最小プロフィールです。
struct WidgetBirthdayPerson: Codable, Identifiable {
    let id: String
    let displayName: String
    let birthMonth: Int
    let birthDay: Int
    let imageColorHex: String
    let imageFileName: String?

    /// 指定した日がこの人の誕生日か判定します。
    func hasBirthday(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        if birthMonth == month, birthDay == day {
            return true
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count
        return birthMonth == 2
            && birthDay == 29
            && month == 2
            && day == 28
            && daysInMonth == 28
    }

    static let samples = [
        WidgetBirthdayPerson(
            id: "sample-1",
            displayName: "あおい",
            birthMonth: 7,
            birthDay: 23,
            imageColorHex: "#4F7CAC",
            imageFileName: nil
        ),
        WidgetBirthdayPerson(
            id: "sample-2",
            displayName: "はると",
            birthMonth: 7,
            birthDay: 23,
            imageColorHex: "#F28C8C",
            imageFileName: nil
        )
    ]
}

/// App Groupに保存された誕生日情報を読み込みます。
struct WidgetBirthdayStore {
    private let defaults = UserDefaults(suiteName: WidgetBirthdayConfiguration.appGroupIdentifier)

    /// 保存済みデータを読み込み、未同期の場合はnilを返します。
    func load() -> [WidgetBirthdayPerson]? {
        guard let data = defaults?.data(forKey: WidgetBirthdayConfiguration.storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode([WidgetBirthdayPerson].self, from: data)
    }

    /// 共有フォルダに保存されたプロフィール画像を読み込みます。
    func profileImage(fileName: String?) -> UIImage? {
        guard let fileName,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              let directoryURL = FileManager.default
                .containerURL(
                    forSecurityApplicationGroupIdentifier: WidgetBirthdayConfiguration.appGroupIdentifier
                )?
                .appendingPathComponent(
                    WidgetBirthdayConfiguration.imageDirectoryName,
                    isDirectory: true
                ),
              let data = try? Data(contentsOf: directoryURL.appendingPathComponent(fileName)) else {
            return nil
        }

        return UIImage(data: data)
    }
}

/// 今日の誕生日をウィジェットのサイズに合わせて表示します。
struct FriendayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: BirthdayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(accentColor)
                Text("今日の誕生日")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if !entry.hasLoadedData {
                UnloadedBirthdayView()
            } else if entry.people.isEmpty {
                EmptyBirthdayView()
            } else {
                birthdayList
            }
        }
        .containerBackground(for: .widget) {
            accentColor.opacity(0.12)
        }
    }

    /// ウィジェットのサイズに合わせて表示人数を変えます。
    private var birthdayList: some View {
        let visiblePeople = Array(entry.people.prefix(maximumVisiblePeople))

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(visiblePeople) { person in
                BirthdayPersonRow(
                    person: person,
                    avatarSize: widgetFamily == .systemSmall ? 52 : 34
                )
            }

            if entry.people.count > maximumVisiblePeople {
                Text("ほか\(entry.people.count - maximumVisiblePeople)人")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Smallでは1人、Mediumでは3人まで表示します。
    private var maximumVisiblePeople: Int {
        widgetFamily == .systemSmall ? 1 : 3
    }

    /// 先頭の人のプロフィールカラーをウィジェット全体に使います。
    private var accentColor: Color {
        guard let firstPerson = entry.people.first else {
            return .orange
        }
        return Color(widgetHex: firstPerson.imageColorHex)
    }
}

/// 誕生日の人をプロフィールカラー付きで1行表示します。
private struct BirthdayPersonRow: View {
    let person: WidgetBirthdayPerson
    let avatarSize: CGFloat

    var body: some View {
        HStack(spacing: 9) {
            avatar

            Text("\(person.displayName)さん")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.displayName)さんの誕生日")
    }

    /// 共有済みのプロフィール画像、または名前の頭文字を表示します。
    @ViewBuilder
    private var avatar: some View {
        if let image = WidgetBirthdayStore().profileImage(fileName: person.imageFileName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color(widgetHex: person.imageColorHex), lineWidth: 2)
                }
        } else {
            Text(String(person.displayName.prefix(1)))
                .font(.system(size: avatarSize * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: avatarSize, height: avatarSize)
                .background(Color(widgetHex: person.imageColorHex))
                .clipShape(Circle())
        }
    }
}

/// 共有データがまだない場合の案内を表示します。
private struct UnloadedBirthdayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Friendayを開いて")
            Text("誕生日を読み込んでください")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 今日の誕生日がいない場合のメッセージを表示します。
private struct EmptyBirthdayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("今日は誕生日の人がいません")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 16進数のプロフィールカラーをSwiftUIの色へ変換します。
private extension Color {
    init(widgetHex: String) {
        let normalized = widgetHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6,
              let value = UInt64(normalized, radix: 16) else {
            self = .orange
            return
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Friendayの「今日の誕生日」ウィジェットです。
struct FriendayWidget: Widget {
    let kind = WidgetBirthdayConfiguration.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            FriendayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日の誕生日")
        .description("Friendayのグループから、今日が誕生日の人を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// アプリ本体とウィジェットで一致させる共有設定です。
private enum WidgetBirthdayConfiguration {
    static let appGroupIdentifier = "group.app.Wakisaka.Wakiso.Frienday"
    static let storageKey = "widgetBirthdayPeople"
    static let imageDirectoryName = "WidgetProfileImages"
    static let kind = "FriendayWidget"
}

#Preview(as: .systemSmall) {
    FriendayWidget()
} timeline: {
    BirthdayEntry(date: .now, people: WidgetBirthdayPerson.samples, hasLoadedData: true)
}

#Preview(as: .systemMedium) {
    FriendayWidget()
} timeline: {
    BirthdayEntry(date: .now, people: WidgetBirthdayPerson.samples, hasLoadedData: true)
    BirthdayEntry(date: .now, people: [], hasLoadedData: true)
}
