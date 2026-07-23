//
//  ProfileImageService.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

/// プロフィール画像のFirebase Storageへの保存と削除を担当します。
struct ProfileImageService {
    static let maximumImageSize = 5 * 1024 * 1024

#if canImport(FirebaseStorage)
    private let storage: Storage

    init(storage: Storage = FirebaseManager.shared.storage) {
        self.storage = storage
    }
#else
    init() {}
#endif

    /// 本人の保存先へ画像を上書きし、Firestoreに保存できるURLを返します。
    func uploadProfileImage(data: Data, contentType: String, userId: String) async throws -> String {
        guard data.count <= Self.maximumImageSize else {
            throw AppError.profileImageTooLarge
        }
        guard contentType.hasPrefix("image/") else {
            throw AppError.invalidProfileImage
        }

#if canImport(FirebaseStorage)
        let reference = profileImageReference(userId: userId)
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        do {
            _ = try await reference.putDataAsync(data, metadata: metadata)
            let downloadURL = try await reference.downloadURL()
            return cacheBustedURLString(from: downloadURL)
        } catch {
            throw AppError.profileImageUploadFailed
        }
#else
        throw AppError.firebaseStorageNotConfigured
#endif
    }

    /// 本人の保存済みプロフィール画像を削除します。
    func deleteProfileImage(userId: String) async throws {
#if canImport(FirebaseStorage)
        do {
            try await profileImageReference(userId: userId).delete()
        } catch {
            throw AppError.profileImageDeleteFailed
        }
#else
        throw AppError.firebaseStorageNotConfigured
#endif
    }

#if canImport(FirebaseStorage)
    /// ユーザーごとに固定された画像パスを返します。
    private func profileImageReference(userId: String) -> StorageReference {
        storage.reference().child("profileImages/\(userId)/profile")
    }

    /// 同じStorageパスに上書きしたときも新しい画像が読み込まれるURLを作ります。
    private func cacheBustedURLString(from url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "version" }
        queryItems.append(URLQueryItem(name: "version", value: UUID().uuidString))
        components.queryItems = queryItems
        return components.url?.absoluteString ?? url.absoluteString
    }
#endif
}
