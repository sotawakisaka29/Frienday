//
//  ChatMessage.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import FirebaseFirestore
import Foundation

/// 送信中、遅延、送信済み、失敗を表すメッセージの状態です。
enum ChatMessageDeliveryState: Hashable {
    case sending
    case delayed
    case sent
    case failed
}

/// 個人チャットで送受信する文字メッセージです。
struct ChatMessage: Identifiable, Hashable {
    var id: String { messageId }

    let messageId: String
    let senderId: String
    let text: String
    let createdAt: Date?
    let clientCreatedAt: Date
    var deliveryState: ChatMessageDeliveryState

    var displayDate: Date {
        createdAt ?? clientCreatedAt
    }

    init(
        messageId: String,
        senderId: String,
        text: String,
        createdAt: Date? = nil,
        clientCreatedAt: Date = Date(),
        deliveryState: ChatMessageDeliveryState = .sent
    ) {
        self.messageId = messageId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.clientCreatedAt = clientCreatedAt
        self.deliveryState = deliveryState
    }

    init?(
        id: String,
        data: [String: Any],
        hasPendingWrites: Bool
    ) {
        guard let senderId = data["senderId"] as? String,
              let text = data["text"] as? String,
              let clientTimestamp = data["clientCreatedAt"] as? Timestamp else {
            return nil
        }

        messageId = id
        self.senderId = senderId
        self.text = text
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        clientCreatedAt = clientTimestamp.dateValue()
        deliveryState = hasPendingWrites ? .sending : .sent
    }

    /// Firestoreへメッセージを送信するときの値です。
    func dataForSend() -> [String: Any] {
        [
            "senderId": senderId,
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
            "clientCreatedAt": Timestamp(date: clientCreatedAt)
        ]
    }

    /// 送信状態だけを変えた新しい値を返します。
    func withDeliveryState(_ deliveryState: ChatMessageDeliveryState) -> ChatMessage {
        ChatMessage(
            messageId: messageId,
            senderId: senderId,
            text: text,
            createdAt: createdAt,
            clientCreatedAt: clientCreatedAt,
            deliveryState: deliveryState
        )
    }
}
