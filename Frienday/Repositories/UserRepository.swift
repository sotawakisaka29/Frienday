//
//  UserRepository.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// ユーザープロフィールの取得・保存を ViewModel に提供します。
struct UserRepository {
    private let userService: UserService

    init(userService: UserService = UserService()) {
        self.userService = userService
    }

    func saveProfile(_ user: AppUser) async throws {
        try await userService.saveProfile(user)
    }

    func fetchProfile(userId: String) async throws -> AppUser {
        try await userService.fetchProfile(userId: userId)
    }

    func fetchPublicProfile(userId: String) async throws -> AppUser {
        try await userService.fetchPublicProfile(userId: userId)
    }

    func updateProfile(_ user: AppUser) async throws {
        try await userService.updateProfile(user)
    }

    func deleteProfile(userId: String) async throws {
        try await userService.deleteProfile(userId: userId)
    }
}
