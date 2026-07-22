//
//  FirebaseRepository.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore

/// Firebase の共通接続を Repository から確認するための小さな入口です。
protocol FirebaseRepositoryProtocol {
    var firestore: Firestore { get }
    func verifyFirestoreConnection() async throws
}

struct FirebaseRepository: FirebaseRepositoryProtocol {
    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    var firestore: Firestore {
        firestoreService.database
    }

    func verifyFirestoreConnection() async throws {
        try await firestoreService.verifyConnection()
    }
}
