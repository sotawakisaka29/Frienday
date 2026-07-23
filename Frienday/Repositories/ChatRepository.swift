//
//  ChatRepository.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation

/// 個人チャット関連の操作をViewModelへ提供します。
struct ChatRepository {
    private let chatService: ChatService

    @MainActor
    init() {
        chatService = ChatService()
    }

    init(chatService: ChatService) {
        self.chatService = chatService
    }

    func synchronizeConnections(userId: String) async throws {
        try await chatService.synchronizeConnections(userId: userId)
    }

    func listenConnections(
        userId: String,
        onChange: @escaping ([ChatConnection], Error?) -> Void
    ) -> ChatListenerCancellation {
        chatService.listenConnections(userId: userId, onChange: onChange)
    }

    func listenBlockedUserIds(
        userId: String,
        onChange: @escaping (Set<String>, Error?) -> Void
    ) -> ChatListenerCancellation {
        chatService.listenBlockedUserIds(userId: userId, onChange: onChange)
    }

    func ensureChat(userId: String, otherUserId: String) async throws -> DirectChat {
        try await chatService.ensureChat(userId: userId, otherUserId: otherUserId)
    }

    func listenMessages(
        chatId: String,
        onChange: @escaping ([ChatMessage], Error?) -> Void
    ) -> ChatListenerCancellation {
        chatService.listenMessages(chatId: chatId, onChange: onChange)
    }

    func sendMessage(chatId: String, message: ChatMessage) async throws {
        try await chatService.sendMessage(chatId: chatId, message: message)
    }

    func deleteMessage(chatId: String, messageId: String) async throws {
        try await chatService.deleteMessage(chatId: chatId, messageId: messageId)
    }

    func reportMessage(
        chatId: String,
        message: ChatMessage,
        reporterId: String,
        reason: ChatReportReason
    ) async throws {
        try await chatService.reportMessage(
            chatId: chatId,
            message: message,
            reporterId: reporterId,
            reason: reason
        )
    }

    func blockUser(userId: String, otherUserId: String) async throws {
        try await chatService.blockUser(userId: userId, otherUserId: otherUserId)
    }

    func unblockUser(userId: String, otherUserId: String) async throws {
        try await chatService.unblockUser(userId: userId, otherUserId: otherUserId)
    }

    func isBlocked(userId: String, otherUserId: String) async throws -> Bool {
        try await chatService.isBlocked(userId: userId, otherUserId: otherUserId)
    }
}
