//
//  UserGroupSummary.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// ユーザー側に保存する所属グループの要約です。
struct UserGroupSummary: Identifiable, Hashable {
    var id: String { groupId }

    let groupId: String
    var name: String
    var role: GroupMemberRole
    var joinedAt: Date?

    init(groupId: String, name: String, role: GroupMemberRole, joinedAt: Date? = nil) {
        self.groupId = groupId
        self.name = name
        self.role = role
        self.joinedAt = joinedAt
    }

    init?(id: String, data: [String: Any]) {
        let roleValue = data["role"] as? String ?? GroupMemberRole.member.rawValue

        guard let name = data["name"] as? String,
              let role = GroupMemberRole(rawValue: roleValue) else {
            return nil
        }

        groupId = id
        self.name = name
        self.role = role
        joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()
    }

    func dataForCreate() -> [String: Any] {
        [
            "groupId": groupId,
            "name": name,
            "role": role.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ]
    }
}
