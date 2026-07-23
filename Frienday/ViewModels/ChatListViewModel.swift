//
//  ChatListViewModel.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation
import Observation

/// チャット可能な相手の一覧とブロック状態を管理します。
@Observable
@MainActor
final class ChatListViewModel {
    private let chatRepository: ChatRepository
    private let userRepository: UserRepository
    private let pushNotificationService: PushNotificationService

    private var connectionListener: ChatListenerCancellation?
    private var blockListener: ChatListenerCancellation?
    private var profileLoadingTask: Task<Void, Never>?
    private var connections: [ChatConnection] = []
    private var blockedUserIds: Set<String> = []

    private(set) var contacts: [ChatContact] = []
    private(set) var isLoading = false
    private(set) var isSynchronizing = false
    private(set) var errorMessage: String?

    init() {
        chatRepository = ChatRepository()
        userRepository = UserRepository()
        pushNotificationService = .shared
    }

    init(
        chatRepository: ChatRepository,
        userRepository: UserRepository,
        pushNotificationService: PushNotificationService
    ) {
        self.chatRepository = chatRepository
        self.userRepository = userRepository
        self.pushNotificationService = pushNotificationService
    }

    /// 共通グループを同期して、相手とブロック状態の監視を始めます。
    func load(userId: String) async {
        stopListening()
        isLoading = true
        errorMessage = nil

        do {
            try await synchronize(userId: userId)
            startListening(userId: userId)
        } catch {
            errorMessage = AppError.map(error).message
            isLoading = false
        }
    }

    /// 引っ張って更新したときに共通グループを再確認します。
    func refresh(userId: String) async {
        do {
            try await synchronize(userId: userId)
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    /// プッシュ通知を許可して現在の端末を登録します。
    func configurePushNotifications(userId: String) async {
        do {
            try await pushNotificationService.requestAuthorizationAndRegister(userId: userId)
        } catch AppError.notificationPermissionDenied {
            errorMessage = AppError.notificationPermissionDenied.message
        } catch AppError.pushNotificationsNotConfigured {
            errorMessage = AppError.pushNotificationsNotConfigured.message
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    /// 画面を閉じたときにFirestoreの監視を終了します。
    func stopListening() {
        connectionListener?()
        blockListener?()
        connectionListener = nil
        blockListener = nil
        profileLoadingTask?.cancel()
        profileLoadingTask = nil
    }

    private func synchronize(userId: String) async throws {
        isSynchronizing = true
        defer { isSynchronizing = false }
        try await chatRepository.synchronizeConnections(userId: userId)
    }

    private func startListening(userId: String) {
        connectionListener = chatRepository.listenConnections(userId: userId) { [weak self] connections, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = AppError.map(error).message
                    self.isLoading = false
                    return
                }
                self.connections = connections
                self.rebuildContacts()
            }
        }

        blockListener = chatRepository.listenBlockedUserIds(userId: userId) { [weak self] blockedUserIds, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = AppError.map(error).message
                    return
                }
                self.blockedUserIds = blockedUserIds
                self.rebuildContacts()
            }
        }
    }

    private func rebuildContacts() {
        profileLoadingTask?.cancel()
        let connections = connections
        let blockedUserIds = blockedUserIds

        profileLoadingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var newContacts: [ChatContact] = []

            for connection in connections {
                guard !Task.isCancelled else { return }
                if let user = try? await userRepository.fetchPublicProfile(userId: connection.otherUserId) {
                    newContacts.append(
                        ChatContact(
                            connection: connection,
                            user: user,
                            isBlocked: blockedUserIds.contains(connection.otherUserId)
                        )
                    )
                }
            }

            contacts = newContacts.sorted {
                $0.user.displayName.localizedStandardCompare($1.user.displayName) == .orderedAscending
            }
            isLoading = false
        }
    }
}
