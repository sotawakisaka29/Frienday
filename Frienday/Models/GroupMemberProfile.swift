//
//  GroupMemberProfile.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation

/// グループ内の公開プロフィールと誕生日表示情報をまとめます。
struct GroupMemberProfile: Identifiable, Hashable {
    var id: String { user.userId }

    let user: AppUser
    let member: GroupMember
    let group: BirthdayGroup
    let nextBirthday: Date?
    let daysUntilBirthday: Int?

    /// グループで設定された公開範囲に合わせて誕生日を表示します。
    var visibleBirthdayText: String {
        guard member.showBirthday else {
            return "誕生日は非公開"
        }

        if member.showBirthYear, let birthYear = member.sharedBirthYear {
            return "\(birthYear)年\(user.birthMonth)月\(user.birthDay)日"
        }
        return user.publicBirthdayText
    }

    /// 次の誕生日までの日数を表示します。
    var daysUntilText: String? {
        guard let daysUntilBirthday else {
            return nil
        }
        return daysUntilBirthday == 0 ? "今日が誕生日です" : "誕生日まであと\(daysUntilBirthday)日"
    }
}
