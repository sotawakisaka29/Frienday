//
//  NotificationSettings.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// 誕生日通知の設定です。
struct NotificationSettings: Codable, Hashable {
    var isEnabled: Bool
    var notifyOnDay: Bool
    var notifyDayBefore: Bool
    var notificationHour: Int
    var notificationMinute: Int

    static let `default` = NotificationSettings(
        isEnabled: false,
        notifyOnDay: true,
        notifyDayBefore: false,
        notificationHour: 9,
        notificationMinute: 0
    )
}
