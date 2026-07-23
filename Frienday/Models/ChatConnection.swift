//
//  ChatConnection.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import FirebaseFirestore
import Foundation

/// 共通グループを通して個人チャットできる相手との接続情報です。
struct ChatConnection: Identifiable, Hashable {
    var id: String { otherUserId }

    let userId: String
    let otherUserId: String
    let activeGroupId: String
    let updatedAt: Date?

    init(userId: String, otherUserId: String, activeGroupId: String, updatedAt: Date? = nil) {
        self.userId = userId
        self.otherUserId = otherUserId
        self.activeGroupId = activeGroupId
        self.updatedAt = updatedAt
    }

    init?(userId: String, id: String, data: [String: Any]) {
        guard let storedUserId = data["userId"] as? String,
              let otherUserId = data["otherUserId"] as? String,
              let activeGroupId = data["activeGroupId"] as? String,
              storedUserId == userId,
              otherUserId == id else {
            return nil
        }

        self.userId = storedUserId
        self.otherUserId = otherUserId
        self.activeGroupId = activeGroupId
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }

    /// Firestoreへ接続情報を保存するときの値です。
    func dataForSave() -> [String: Any] {
        [
            "userId": userId,
            "otherUserId": otherUserId,
            "activeGroupId": activeGroupId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

/// チャット一覧に表示する相手の情報です。
struct ChatContact: Identifiable, Hashable {
    var id: String { connection.otherUserId }

    let connection: ChatConnection
    let user: AppUser
    let isBlocked: Bool

    var chatId: String {
        DirectChat.makeId(
            userId: connection.userId,
            otherUserId: connection.otherUserId
        )
    }
}
