//
//  FirestoreService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore

/// Firestore への接続確認を担当します。
struct FirestoreService {
    let database: Firestore

    init(database: Firestore = FirebaseManager.shared.firestore) {
        self.database = database
    }

    /// Firestore のインスタンス取得と軽い読み取りで接続状態を確認します。
    func verifyConnection() async throws {
        _ = try await database.collection("_health").limit(to: 1).getDocuments()
    }
}
