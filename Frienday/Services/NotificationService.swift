//
//  NotificationService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import UserNotifications

/// UNUserNotificationCenter を使ってローカル通知を登録します。
struct NotificationService {
    private static let settingsKey = "frienday.notificationSettings"

    private let center: UNUserNotificationCenter
    private let birthdayService: BirthdayCalculationService
    private let userDefaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        birthdayService: BirthdayCalculationService = BirthdayCalculationService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center
        self.birthdayService = birthdayService
        self.userDefaults = userDefaults
    }

    /// 端末に保存されている通知設定を読み込みます。
    func loadSettings() -> NotificationSettings {
        guard let data = userDefaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// 通知設定を次回起動時にも使えるよう端末へ保存します。
    func saveSettings(_ settings: NotificationSettings) throws {
        let data = try JSONEncoder().encode(settings)
        userDefaults.set(data, forKey: Self.settingsKey)
    }

    func requestAuthorizationIfNeeded() async throws {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return
        }

        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { throw AppError.notificationPermissionDenied }
    }

    func registerBirthdayNotifications(items: [BirthdayDisplayItem], settings: NotificationSettings) async throws {
        removeFriendayNotifications()
        guard settings.isEnabled else { return }
        try await requestAuthorizationIfNeeded()

        for item in birthdayService.uniqueBirthdayItems(items) {
            if settings.notifyOnDay {
                try await addNotification(item: item, settings: settings, dayOffset: 0)
            }

            if settings.notifyDayBefore {
                try await addNotification(item: item, settings: settings, dayOffset: -1)
            }
        }
    }

    func removeFriendayNotifications() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("frienday-birthday-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 登録済み通知と端末に保存した設定を削除します。
    func clearSettings() {
        removeFriendayNotifications()
        userDefaults.removeObject(forKey: Self.settingsKey)
    }

    private func addNotification(item: BirthdayDisplayItem, settings: NotificationSettings, dayOffset: Int) async throws {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = dayOffset == 0 ? "今日は誕生日です" : "明日は誕生日です"
        content.body = "\(item.user.displayName)さんの誕生日をお祝いしましょう。"

        let fireDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: item.nextBirthday) ?? item.nextBirthday
        var components = Calendar.current.dateComponents([.month, .day], from: fireDate)
        components.hour = settings.notificationHour
        components.minute = settings.notificationMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "frienday-birthday-\(item.user.userId)-\(dayOffset)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }
}
