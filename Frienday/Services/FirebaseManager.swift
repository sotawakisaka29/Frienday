//
//  FirebaseManager.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Firebase の初期化と共通インスタンスを管理します。
final class FirebaseManager {
    static let shared = FirebaseManager()

    private var isConfigured = false

    var auth: Auth {
        configure()
        return Auth.auth()
    }

    var firestore: Firestore {
        configure()
        return Firestore.firestore()
    }

    private init() {}

    func configure() {
        guard !isConfigured else { return }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            preconditionFailure("GoogleService-Info.plist がアプリターゲットに含まれているか確認してください。")
        }

        FirebaseApp.configure()
        isConfigured = true
    }
}
