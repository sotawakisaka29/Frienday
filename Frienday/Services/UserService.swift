//
//  UserService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// Firestore のユーザープロフィールを読み書きします。
struct UserService {
    private let database: Firestore

    init(database: Firestore = FirebaseManager.shared.firestore) {
        self.database = database
    }

    func saveProfile(_ user: AppUser) async throws {
        let batch = database.batch()
        let userRef = database.collection("users").document(user.userId)
        batch.setData(user.dataForCreate(), forDocument: userRef, merge: true)
        batch.setData(user.dataForPublicProfile(), forDocument: database.collection("publicProfiles").document(user.userId), merge: true)
        batch.setData(user.dataForPrivateProfile(), forDocument: database.collection("privateProfiles").document(user.userId), merge: true)

        do {
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchProfile(userId: String) async throws -> AppUser {
        do {
            let publicSnapshot = try await database.collection("publicProfiles").document(userId).getDocument()
            let privateSnapshot = try await database.collection("privateProfiles").document(userId).getDocument()

            guard var data = publicSnapshot.data(),
                  let privateData = privateSnapshot.data(),
                  let email = privateData["email"] as? String,
                  let birthYear = privateData["birthYear"] as? Int ?? data["birthYear"] as? Int else {
                throw AppError.notSignedIn
            }

            data["email"] = email
            data["birthYear"] = birthYear
            guard let user = AppUser(id: publicSnapshot.documentID, data: data) else {
                throw AppError.notSignedIn
            }

            if publicSnapshot.data()?["birthYear"] != nil {
                let batch = database.batch()
                batch.setData(
                    ["birthYear": birthYear],
                    forDocument: database.collection("privateProfiles").document(userId),
                    merge: true
                )
                batch.updateData(
                    ["birthYear": FieldValue.delete()],
                    forDocument: database.collection("publicProfiles").document(userId)
                )
                try? await batch.commit()
            }

            return user
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchPublicProfile(userId: String) async throws -> AppUser {
        do {
            let snapshot = try await database.collection("publicProfiles").document(userId).getDocument()
            guard var data = snapshot.data() else {
                throw AppError.notSignedIn
            }
            data["email"] = ""
            data["birthYear"] = 0
            guard let user = AppUser(id: snapshot.documentID, data: data) else {
                throw AppError.notSignedIn
            }
            return user
        } catch {
            throw AppError.map(error)
        }
    }

    func updateProfile(_ user: AppUser) async throws {
        let batch = database.batch()
        batch.setData(user.dataForPublicUpdate(), forDocument: database.collection("publicProfiles").document(user.userId), merge: true)
        batch.setData(user.dataForPrivateUpdate(), forDocument: database.collection("privateProfiles").document(user.userId), merge: true)

        do {
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }

    func deleteProfile(userId: String) async throws {
        let batch = database.batch()
        batch.deleteDocument(database.collection("publicProfiles").document(userId))
        batch.deleteDocument(database.collection("privateProfiles").document(userId))
        batch.deleteDocument(database.collection("users").document(userId))

        do {
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }
}
