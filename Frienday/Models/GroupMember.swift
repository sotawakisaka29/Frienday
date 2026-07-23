//
//  GroupMember.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// グループ内での役割です。
enum GroupMemberRole: String, Codable, Hashable {
    case owner
    case member

    var label: String {
        switch self {
        case .owner: return "オーナー"
        case .member: return "メンバー"
        }
    }
}

/// グループに所属しているメンバー情報です。
struct GroupMember: Identifiable, Hashable {
    var id: String { userId }

    let userId: String
    var role: GroupMemberRole
    var joinedAt: Date?
    var showBirthday: Bool
    var showBirthYear: Bool
    var sharedBirthYear: Int?

    init(
        userId: String,
        role: GroupMemberRole,
        joinedAt: Date? = nil,
        showBirthday: Bool = true,
        showBirthYear: Bool = false,
        sharedBirthYear: Int? = nil
    ) {
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
        self.showBirthday = showBirthday
        self.showBirthYear = showBirthYear
        self.sharedBirthYear = sharedBirthYear
    }

    init?(id: String, data: [String: Any]) {
        let roleValue = data["role"] as? String ?? GroupMemberRole.member.rawValue

        guard let role = GroupMemberRole(rawValue: roleValue) else {
            return nil
        }

        userId = id
        self.role = role
        joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()
        showBirthday = data["showBirthday"] as? Bool ?? true
        showBirthYear = data["showBirthYear"] as? Bool ?? false
        sharedBirthYear = data["birthYear"] as? Int
    }

    func dataForCreate() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "role": role.rawValue,
            "joinedAt": FieldValue.serverTimestamp(),
            "showBirthday": showBirthday,
            "showBirthYear": showBirthYear
        ]

        if let sharedBirthYear {
            data["birthYear"] = sharedBirthYear
        }
        return data
    }
}
