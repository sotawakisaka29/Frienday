//
//  ChatService.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import FirebaseFirestore
import Foundation
import OSLog

/// Firestoreのリアルタイム監視を終了する処理です。
typealias ChatListenerCancellation = () -> Void

/// 個人チャット、接続、ブロック、通報をFirestoreで管理します。
struct ChatService {
    private static let maximumBatchOperations = 400
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Frienday",
        category: "DirectChat"
    )

    private let database: Firestore

    @MainActor
    init() {
        database = FirebaseManager.shared.firestore
    }

    init(database: Firestore) {
        self.database = database
    }

    /// 現在共有しているグループから、チャット可能な相手との接続情報を同期します。
    func synchronizeConnections(userId: String) async throws {
        do {
            let userGroupsSnapshot = try await database
                .collection("users")
                .document(userId)
                .collection("groups")
                .getDocuments()

            var desiredGroupByUserId: [String: String] = [:]
            for groupDocument in userGroupsSnapshot.documents {
                let groupId = groupDocument.documentID
                let membersSnapshot = try await database
                    .collection("groups")
                    .document(groupId)
                    .collection("members")
                    .getDocuments()

                for memberDocument in membersSnapshot.documents where memberDocument.documentID != userId {
                    if desiredGroupByUserId[memberDocument.documentID] == nil {
                        desiredGroupByUserId[memberDocument.documentID] = groupId
                    }
                }
            }

            let connectionsRef = database
                .collection("users")
                .document(userId)
                .collection("connections")
            let existingSnapshot = try await connectionsRef.getDocuments()
            var existingConnections: [String: ChatConnection] = [:]
            for document in existingSnapshot.documents {
                guard let connection = ChatConnection(
                    userId: userId,
                    id: document.documentID,
                    data: document.data()
                ) else {
                    continue
                }
                existingConnections[connection.otherUserId] = connection
            }

            var mutations: [ConnectionMutation] = []

            for (otherUserId, groupId) in desiredGroupByUserId {
                guard existingConnections[otherUserId]?.activeGroupId != groupId else { continue }
                mutations.append(.save(userId: userId, otherUserId: otherUserId, groupId: groupId))
            }

            for otherUserId in existingConnections.keys where desiredGroupByUserId[otherUserId] == nil {
                mutations.append(.delete(userId: userId, otherUserId: otherUserId))
            }

            try await commitConnectionMutations(mutations)
        } catch {
            throw AppError.map(error)
        }
    }

    /// チャット可能な相手の変更をリアルタイムで受け取ります。
    func listenConnections(
        userId: String,
        onChange: @escaping ([ChatConnection], Error?) -> Void
    ) -> ChatListenerCancellation {
        let listener = database
            .collection("users")
            .document(userId)
            .collection("connections")
            .addSnapshotListener { snapshot, error in
                guard let snapshot else {
                    onChange([], error)
                    return
                }

                let connections = snapshot.documents.compactMap { document in
                    ChatConnection(userId: userId, id: document.documentID, data: document.data())
                }
                onChange(connections, error)
            }

        return {
            listener.remove()
        }
    }

    /// 自分がブロックしているユーザーの変更をリアルタイムで受け取ります。
    func listenBlockedUserIds(
        userId: String,
        onChange: @escaping (Set<String>, Error?) -> Void
    ) -> ChatListenerCancellation {
        let listener = database
            .collection("users")
            .document(userId)
            .collection("blockedUsers")
            .addSnapshotListener { snapshot, error in
                guard let snapshot else {
                    onChange([], error)
                    return
                }

                onChange(Set(snapshot.documents.map(\.documentID)), error)
            }

        return {
            listener.remove()
        }
    }

    /// まだ存在しない場合だけ、2人の個人チャットを作成します。
    func ensureChat(userId: String, otherUserId: String) async throws -> DirectChat {
        let chatId = DirectChat.makeId(userId: userId, otherUserId: otherUserId)
        let chatRef = database.collection("directChats").document(chatId)
        let chat = DirectChat(chatId: chatId, participantIds: [userId, otherUserId])

        do {
            let snapshot = try await chatRef.getDocument()
            if let storedChat = try validatedChat(from: snapshot, expected: chat) {
                return storedChat
            }
        } catch {
            // 未作成ドキュメントの読み取りはルール上permission-deniedになるため、
            // その場合だけ安全なcreateを続行します。
            guard AppError.map(error) == .permissionDenied else {
                logFirebaseError(error, operation: "ensureChat.read")
                throw AppError.map(error)
            }
        }

        do {
            try await chatRef.setData(chat.dataForCreate())
            return chat
        } catch {
            let createError = error

            // 2人が同時に初回画面を開いた場合は、先に作成された内容を採用します。
            if let snapshot = try? await chatRef.getDocument(),
               let storedChat = try? validatedChat(from: snapshot, expected: chat) {
                return storedChat
            }

            logFirebaseError(createError, operation: "ensureChat.create")
            throw AppError.map(error)
        }
    }

    /// 最新100件のメッセージと送信状態をリアルタイムで受け取ります。
    func listenMessages(
        chatId: String,
        onChange: @escaping ([ChatMessage], Error?) -> Void
    ) -> ChatListenerCancellation {
        let listener = database
            .collection("directChats")
            .document(chatId)
            .collection("messages")
            .order(by: "createdAt")
            .limit(toLast: 100)
            .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                guard let snapshot else {
                    onChange([], error)
                    return
                }

                let messages = snapshot.documents
                    .compactMap { document in
                        ChatMessage(
                            id: document.documentID,
                            data: document.data(),
                            hasPendingWrites: document.metadata.hasPendingWrites
                        )
                    }
                    .sorted {
                        if $0.displayDate == $1.displayDate {
                            return $0.messageId < $1.messageId
                        }
                        return $0.displayDate < $1.displayDate
                    }
                onChange(messages, error)
            }

        return {
            listener.remove()
        }
    }

    /// 50文字以内の文字メッセージを送信します。
    func sendMessage(chatId: String, message: ChatMessage) async throws {
        let text = try ValidationUtility.validateChatMessage(message.text)
        let validatedMessage = ChatMessage(
            messageId: message.messageId,
            senderId: message.senderId,
            text: text,
            createdAt: message.createdAt,
            clientCreatedAt: message.clientCreatedAt,
            deliveryState: message.deliveryState
        )

        do {
            try await database
                .collection("directChats")
                .document(chatId)
                .collection("messages")
                .document(message.messageId)
                .setData(validatedMessage.dataForSend())
        } catch {
            logFirebaseError(error, operation: "sendMessage")
            throw AppError.map(error)
        }
    }

    /// 本文やユーザー情報を含めず、原因の特定に必要なFirebaseのエラーだけを記録します。
    private func logFirebaseError(_ error: Error, operation: String) {
        let nsError = error as NSError
        Self.logger.error(
            "\(operation, privacy: .public) failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) description=\(nsError.localizedDescription, privacy: .public)"
        )
    }

    private func validatedChat(
        from snapshot: DocumentSnapshot,
        expected chat: DirectChat
    ) throws -> DirectChat? {
        guard snapshot.exists else { return nil }
        guard let data = snapshot.data(),
              let storedChat = DirectChat(id: snapshot.documentID, data: data),
              storedChat.participantIds == chat.participantIds else {
            throw AppError.chatUnavailable
        }
        return storedChat
    }

    /// 送信者本人のメッセージを削除します。
    func deleteMessage(chatId: String, messageId: String) async throws {
        do {
            try await database
                .collection("directChats")
                .document(chatId)
                .collection("messages")
                .document(messageId)
                .delete()
        } catch {
            throw AppError.map(error)
        }
    }

    /// 不適切なメッセージを運営確認用のreportsコレクションへ送ります。
    func reportMessage(
        chatId: String,
        message: ChatMessage,
        reporterId: String,
        reason: ChatReportReason
    ) async throws {
        guard message.senderId != reporterId, let sentAt = message.createdAt else {
            throw AppError.chatReportFailed
        }

        let reportRef = database.collection("reports").document()
        let data: [String: Any] = [
            "chatId": chatId,
            "messageId": message.messageId,
            "reporterId": reporterId,
            "reportedUserId": message.senderId,
            "reason": reason.rawValue,
            "messageText": message.text,
            "messageSentAt": Timestamp(date: sentAt),
            "createdAt": FieldValue.serverTimestamp(),
            "status": "open"
        ]

        do {
            try await reportRef.setData(data)
        } catch {
            throw AppError.map(error)
        }
    }

    /// 指定した相手からの新しいメッセージを拒否します。
    func blockUser(userId: String, otherUserId: String) async throws {
        let data: [String: Any] = [
            "blockerId": userId,
            "blockedUserId": otherUserId,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            try await database
                .collection("users")
                .document(userId)
                .collection("blockedUsers")
                .document(otherUserId)
                .setData(data)
        } catch {
            throw AppError.map(error)
        }
    }

    /// 指定した相手のブロックを解除します。
    func unblockUser(userId: String, otherUserId: String) async throws {
        do {
            try await database
                .collection("users")
                .document(userId)
                .collection("blockedUsers")
                .document(otherUserId)
                .delete()
        } catch {
            throw AppError.map(error)
        }
    }

    /// 自分が指定した相手をブロックしているか取得します。
    func isBlocked(userId: String, otherUserId: String) async throws -> Bool {
        do {
            let snapshot = try await database
                .collection("users")
                .document(userId)
                .collection("blockedUsers")
                .document(otherUserId)
                .getDocument()
            return snapshot.exists
        } catch {
            throw AppError.map(error)
        }
    }

    private func commitConnectionMutations(_ mutations: [ConnectionMutation]) async throws {
        guard !mutations.isEmpty else { return }

        let mutationsPerBatch = Self.maximumBatchOperations / 2
        for startIndex in stride(from: 0, to: mutations.count, by: mutationsPerBatch) {
            let endIndex = min(startIndex + mutationsPerBatch, mutations.count)
            let batch = database.batch()

            for mutation in mutations[startIndex..<endIndex] {
                switch mutation {
                case .save(let userId, let otherUserId, let groupId):
                    let forward = ChatConnection(
                        userId: userId,
                        otherUserId: otherUserId,
                        activeGroupId: groupId
                    )
                    let reverse = ChatConnection(
                        userId: otherUserId,
                        otherUserId: userId,
                        activeGroupId: groupId
                    )
                    batch.setData(
                        forward.dataForSave(),
                        forDocument: connectionReference(userId: userId, otherUserId: otherUserId),
                        merge: true
                    )
                    batch.setData(
                        reverse.dataForSave(),
                        forDocument: connectionReference(userId: otherUserId, otherUserId: userId),
                        merge: true
                    )
                case .delete(let userId, let otherUserId):
                    batch.deleteDocument(connectionReference(userId: userId, otherUserId: otherUserId))
                    batch.deleteDocument(connectionReference(userId: otherUserId, otherUserId: userId))
                }
            }

            try await batch.commit()
        }
    }

    private func connectionReference(userId: String, otherUserId: String) -> DocumentReference {
        database
            .collection("users")
            .document(userId)
            .collection("connections")
            .document(otherUserId)
    }
}

/// 接続情報を対になる2つの文書へ反映する操作です。
private enum ConnectionMutation {
    case save(userId: String, otherUserId: String, groupId: String)
    case delete(userId: String, otherUserId: String)
}
