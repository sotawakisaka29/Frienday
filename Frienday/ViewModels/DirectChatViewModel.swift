//
//  DirectChatViewModel.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation
import Observation

/// 1対1のメッセージ、送信状態、削除、通報、ブロックを管理します。
@Observable
@MainActor
final class DirectChatViewModel {
    private let chatRepository: ChatRepository
    private var messageListener: ChatListenerCancellation?
    private var remoteMessages: [String: ChatMessage] = [:]
    private var localMessages: [String: ChatMessage] = [:]
    private var delayTasks: [String: Task<Void, Never>] = [:]
    private var currentUserId: String?

    let contact: ChatContact
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = true
    private(set) var isChatAvailable = false
    private(set) var isBlocked: Bool
    private(set) var isUpdatingBlock = false
    private(set) var errorMessage: String?
    private(set) var successMessage: String?

    init(contact: ChatContact) {
        self.contact = contact
        chatRepository = ChatRepository()
        isBlocked = contact.isBlocked
    }

    init(contact: ChatContact, chatRepository: ChatRepository) {
        self.contact = contact
        self.chatRepository = chatRepository
        isBlocked = contact.isBlocked
    }

    var remainingCharacterCount: Int {
        max(0, 50 - draft.count)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.count <= 50
            && !isBlocked
            && isChatAvailable
    }

    /// チャットを用意して、最新メッセージのリアルタイム監視を始めます。
    func start(userId: String) async {
        stop()
        currentUserId = userId
        isLoading = true
        isChatAvailable = false
        errorMessage = nil

        do {
            isBlocked = try await chatRepository.isBlocked(
                userId: userId,
                otherUserId: contact.user.userId
            )
            _ = try await chatRepository.ensureChat(
                userId: userId,
                otherUserId: contact.user.userId
            )
            isChatAvailable = true
            startMessageListener()
        } catch {
            let appError = AppError.map(error)
            errorMessage = appError == .permissionDenied
                ? AppError.chatUnavailable.message
                : appError.message
            isChatAvailable = false
            isLoading = false
        }
    }

    /// 入力中の文字数を50文字以内に保ちます。
    func updateDraft(_ value: String) {
        draft = String(value.prefix(50))
        clearFeedback()
    }

    /// 入力中の本文を送信し、通信中・遅延・失敗状態を画面へ反映します。
    func send(isConnected: Bool) async {
        guard let currentUserId else {
            errorMessage = AppError.notSignedIn.message
            return
        }
        guard isChatAvailable else {
            errorMessage = AppError.chatUnavailable.message
            return
        }

        let submittedDraft = draft
        let text: String
        do {
            text = try ValidationUtility.validateChatMessage(submittedDraft)
        } catch {
            errorMessage = AppError.map(error).message
            return
        }

        let message = ChatMessage(
            messageId: UUID().uuidString.lowercased(),
            senderId: currentUserId,
            text: text,
            clientCreatedAt: Date(),
            deliveryState: isConnected ? .sending : .failed
        )
        localMessages[message.messageId] = message
        rebuildMessages()

        guard isConnected else {
            errorMessage = AppError.chatSendFailed.message
            return
        }

        if await send(message), draft == submittedDraft {
            draft = ""
        }
    }

    /// 失敗したメッセージを同じIDで再送し、重複を防ぎます。
    func retry(_ message: ChatMessage, isConnected: Bool) async {
        guard message.senderId == currentUserId else { return }
        guard isChatAvailable else {
            errorMessage = AppError.chatUnavailable.message
            return
        }
        guard isConnected else {
            errorMessage = AppError.chatSendFailed.message
            return
        }

        localMessages[message.messageId] = message.withDeliveryState(.sending)
        rebuildMessages()
        _ = await send(message.withDeliveryState(.sending))
    }

    /// 自分が送ったメッセージだけを削除します。
    func delete(_ message: ChatMessage) async {
        guard message.senderId == currentUserId else { return }

        if message.deliveryState == .failed {
            localMessages.removeValue(forKey: message.messageId)
            rebuildMessages()
            return
        }

        do {
            try await chatRepository.deleteMessage(
                chatId: contact.chatId,
                messageId: message.messageId
            )
            clearFeedback()
        } catch {
            errorMessage = AppError.chatDeleteFailed.message
        }
    }

    /// 相手の不適切なメッセージを運営確認用として通報します。
    func report(_ message: ChatMessage, reason: ChatReportReason) async {
        guard let currentUserId, message.senderId != currentUserId else { return }

        do {
            try await chatRepository.reportMessage(
                chatId: contact.chatId,
                message: message,
                reporterId: currentUserId,
                reason: reason
            )
            successMessage = "通報を受け付けました。運営が内容を確認します。"
            errorMessage = nil
        } catch {
            errorMessage = AppError.chatReportFailed.message
            successMessage = nil
        }
    }

    /// 現在の状態に応じて相手のブロックと解除を切り替えます。
    func toggleBlock() async {
        guard let currentUserId, !isUpdatingBlock else { return }
        isUpdatingBlock = true
        defer { isUpdatingBlock = false }

        do {
            if isBlocked {
                try await chatRepository.unblockUser(
                    userId: currentUserId,
                    otherUserId: contact.user.userId
                )
                isBlocked = false
                successMessage = "ブロックを解除しました。"
            } else {
                try await chatRepository.blockUser(
                    userId: currentUserId,
                    otherUserId: contact.user.userId
                )
                isBlocked = true
                successMessage = "この相手をブロックしました。"
            }
            errorMessage = nil
        } catch {
            errorMessage = AppError.map(error).message
            successMessage = nil
        }
    }

    /// 画面を閉じたときに監視と遅延判定を終了します。
    func stop() {
        messageListener?()
        messageListener = nil
        for task in delayTasks.values {
            task.cancel()
        }
        delayTasks.removeAll()
    }

    func clearFeedback() {
        errorMessage = nil
        successMessage = nil
    }

    private func startMessageListener() {
        messageListener = chatRepository.listenMessages(chatId: contact.chatId) { [weak self] messages, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    let appError = AppError.map(error)
                    self.errorMessage = appError == .permissionDenied
                        ? AppError.chatUnavailable.message
                        : appError.message
                    self.isChatAvailable = false
                    self.isLoading = false
                    return
                }

                self.remoteMessages = Dictionary(uniqueKeysWithValues: messages.map { ($0.messageId, $0) })
                for message in messages where message.deliveryState == .sent {
                    self.localMessages.removeValue(forKey: message.messageId)
                    self.delayTasks[message.messageId]?.cancel()
                    self.delayTasks.removeValue(forKey: message.messageId)
                }
                self.rebuildMessages()
                self.isLoading = false
            }
        }
    }

    /// Firebaseへの保存に成功したかを返します。
    private func send(_ message: ChatMessage) async -> Bool {
        scheduleDelayNotice(messageId: message.messageId)

        do {
            try await chatRepository.sendMessage(chatId: contact.chatId, message: message)
            return true
        } catch {
            delayTasks[message.messageId]?.cancel()
            delayTasks.removeValue(forKey: message.messageId)
            localMessages[message.messageId] = message.withDeliveryState(.failed)
            errorMessage = AppError.chatSendFailed.message
            rebuildMessages()
            return false
        }
    }

    private func scheduleDelayNotice(messageId: String) {
        delayTasks[messageId]?.cancel()
        delayTasks[messageId] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled,
                  let self,
                  let message = self.localMessages[messageId],
                  message.deliveryState == .sending else {
                return
            }
            self.localMessages[messageId] = message.withDeliveryState(.delayed)
            self.rebuildMessages()
        }
    }

    private func rebuildMessages() {
        let allIds = Set(remoteMessages.keys).union(localMessages.keys)
        messages = allIds.compactMap { messageId in
            if let remoteMessage = remoteMessages[messageId],
               remoteMessage.deliveryState == .sent {
                return remoteMessage
            }
            return localMessages[messageId] ?? remoteMessages[messageId]
        }
        .sorted {
            if $0.displayDate == $1.displayDate {
                return $0.messageId < $1.messageId
            }
            return $0.displayDate < $1.displayDate
        }
    }
}
