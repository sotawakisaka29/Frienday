//
//  PushNotificationService.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import Foundation
import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// チャット通知の許可要求と、この端末の通知登録情報を管理します。
@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private static let deviceIdKey = "frienday.push.deviceId"
    private static let userIdKey = "frienday.push.userId"

    private let database: Firestore
    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private var registrationToken: String?

    private init() {
        database = FirebaseManager.shared.firestore
        center = .current()
        userDefaults = .standard
    }

    /// 通知許可を確認して、現在の端末をログイン中ユーザーへ登録します。
    func requestAuthorizationAndRegister(userId: String) async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { throw AppError.notificationPermissionDenied }
        case .denied:
            throw AppError.notificationPermissionDenied
        @unknown default:
            throw AppError.notificationPermissionDenied
        }

        UIApplication.shared.registerForRemoteNotifications()

#if canImport(FirebaseMessaging)
        let token = try await Messaging.messaging().token()
        try await register(token: token, userId: userId)
#else
        throw AppError.pushNotificationsNotConfigured
#endif
    }

    /// Firebase Messagingから更新されたトークンを受け取って保存します。
    func receiveRegistrationToken(_ token: String) async {
        registrationToken = token
        guard let userId = Auth.auth().currentUser?.uid else { return }
        try? await register(token: token, userId: userId)
    }

    /// ログアウト前に、この端末へのチャット通知登録を解除します。
    func unregisterCurrentDevice(userId: String) async {
        guard let storedDeviceId = userDefaults.string(forKey: Self.deviceIdKey),
              userDefaults.string(forKey: Self.userIdKey) == userId else {
            return
        }

        try? await database
            .collection("users")
            .document(userId)
            .collection("devices")
            .document(storedDeviceId)
            .delete()
        clearStoredRegistration()
    }

    private func register(token: String, userId: String) async throws {
        registrationToken = token
        let deviceId = hashedToken(token)

        if let previousDeviceId = userDefaults.string(forKey: Self.deviceIdKey),
           let previousUserId = userDefaults.string(forKey: Self.userIdKey),
           previousUserId == userId,
           previousDeviceId != deviceId {
            try? await database
                .collection("users")
                .document(userId)
                .collection("devices")
                .document(previousDeviceId)
                .delete()
        }

        let data: [String: Any] = [
            "userId": userId,
            "token": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await database
            .collection("users")
            .document(userId)
            .collection("devices")
            .document(deviceId)
            .setData(data)

        userDefaults.set(deviceId, forKey: Self.deviceIdKey)
        userDefaults.set(userId, forKey: Self.userIdKey)
    }

    private func hashedToken(_ token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func clearStoredRegistration() {
        userDefaults.removeObject(forKey: Self.deviceIdKey)
        userDefaults.removeObject(forKey: Self.userIdKey)
    }
}
