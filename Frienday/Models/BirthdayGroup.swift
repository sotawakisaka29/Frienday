//
//  BirthdayGroup.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// 誕生日を共有するグループです。
struct BirthdayGroup: Identifiable, Hashable {
    var id: String { groupId }

    let groupId: String
    var name: String
    var ownerId: String
    var inviteCode: String
    var createdAt: Date?
    var updatedAt: Date?

    init(groupId: String, name: String, ownerId: String, inviteCode: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.groupId = groupId
        self.name = name
        self.ownerId = ownerId
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let ownerId = data["ownerId"] as? String,
              let inviteCode = data["inviteCode"] as? String else {
            return nil
        }

        groupId = id
        self.name = name
        self.ownerId = ownerId
        self.inviteCode = inviteCode
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }

    func dataForCreate() -> [String: Any] {
        [
            "groupId": groupId,
            "name": name,
            "ownerId": ownerId,
            "inviteCode": inviteCode,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
