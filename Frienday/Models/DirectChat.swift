//
//  DirectChat.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import CryptoKit
import FirebaseFirestore
import Foundation

/// 2人だけが参加する個人チャットです。
struct DirectChat: Identifiable, Hashable {
    var id: String { chatId }

    let chatId: String
    let participantIds: [String]
    let createdAt: Date?

    init(chatId: String, participantIds: [String], createdAt: Date? = nil) {
        self.chatId = chatId
        self.participantIds = participantIds.sorted()
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        guard let participantIds = data["participantIds"] as? [String],
              participantIds.count == 2 else {
            return nil
        }

        chatId = id
        self.participantIds = participantIds.sorted()
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }

    /// 参加者の組み合わせから、順番に左右されないチャットIDを作ります。
    static func makeId(userId: String, otherUserId: String) -> String {
        let source = [userId, otherUserId].sorted().joined(separator: "\u{0}")
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Firestoreへ新しいチャットを作成するときの値です。
    func dataForCreate() -> [String: Any] {
        [
            "participantIds": participantIds,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
