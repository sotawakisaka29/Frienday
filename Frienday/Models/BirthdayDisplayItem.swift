//
//  BirthdayDisplayItem.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// 画面表示用にプロフィールとグループ情報をまとめた誕生日データです。
struct BirthdayDisplayItem: Identifiable, Hashable {
    var id: String { "\(user.userId)-\(group.groupId)" }

    let user: AppUser
    let group: BirthdayGroup
    let member: GroupMember
    let nextBirthday: Date
    let daysUntilBirthday: Int

    var visibleBirthdayText: String {
        if member.showBirthYear, let birthYear = member.sharedBirthYear {
            return "\(birthYear)年\(user.birthMonth)月\(user.birthDay)日"
        }
        return user.publicBirthdayText
    }
}
