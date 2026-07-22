//
//  GroupListViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import Observation

/// グループ一覧、作成、招待コード参加を管理します。
@Observable
@MainActor
final class GroupListViewModel {
    private let groupRepository: GroupRepository
    private let userRepository: UserRepository
    private let birthdayService: BirthdayCalculationService

    private(set) var groups: [BirthdayGroup] = []
    private(set) var summaries: [String: GroupSummary] = [:]
    private(set) var isLoading = false
    private(set) var isProcessing = false
    private(set) var errorMessage: String?

    init(
        groupRepository: GroupRepository = GroupRepository(),
        userRepository: UserRepository = UserRepository(),
        birthdayService: BirthdayCalculationService = BirthdayCalculationService()
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.birthdayService = birthdayService
    }

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            groups = try await groupRepository.fetchUserGroups(userId: userId)
            summaries = try await buildSummaries(groups: groups)
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }

    func createGroup(name: String, userId: String) async -> BirthdayGroup? {
        guard !isProcessing else { return nil }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let group = try await groupRepository.createGroup(name: name, ownerId: userId)
            await load(userId: userId)
            return group
        } catch {
            errorMessage = AppError.map(error).message
            return nil
        }
    }

    func joinGroup(inviteCode: String, userId: String) async -> Bool {
        guard !isProcessing else { return false }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await groupRepository.joinGroup(inviteCode: inviteCode, userId: userId)
            await load(userId: userId)
            return true
        } catch {
            errorMessage = AppError.map(error).message
            return false
        }
    }

    /// 新しい操作を開始する前に、前回のエラー表示を消去します。
    func clearError() {
        errorMessage = nil
    }

    private func buildSummaries(groups: [BirthdayGroup]) async throws -> [String: GroupSummary] {
        var results: [String: GroupSummary] = [:]

        for group in groups {
            let members = try await groupRepository.fetchMembers(groupId: group.groupId)
            var users: [AppUser] = []

            for member in members where member.showBirthday {
                if let user = try? await userRepository.fetchPublicProfile(userId: member.userId) {
                    users.append(user)
                }
            }

            let items = birthdayService.birthdayItems(users: users, members: members, group: group)
            results[group.groupId] = GroupSummary(memberCount: members.count, nextBirthdayItem: items.first)
        }

        return results
    }
}

/// グループ一覧に表示する要約です。
struct GroupSummary: Hashable {
    let memberCount: Int
    let nextBirthdayItem: BirthdayDisplayItem?
}
