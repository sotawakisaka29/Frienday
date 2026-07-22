//
//  HomeViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import Observation

/// ホーム画面に表示する誕生日情報を管理します。
@Observable
@MainActor
final class HomeViewModel {
    private let groupRepository: GroupRepository
    private let userRepository: UserRepository
    private let birthdayService: BirthdayCalculationService

    private(set) var groups: [BirthdayGroup] = []
    private(set) var allBirthdayItems: [BirthdayDisplayItem] = []
    private(set) var selectedGroupId: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// 選択中のグループに含まれる直近5人の誕生日です。
    var upcomingItems: [BirthdayDisplayItem] {
        let filteredItems: [BirthdayDisplayItem]
        if let selectedGroupId {
            filteredItems = allBirthdayItems.filter { $0.group.groupId == selectedGroupId }
        } else {
            filteredItems = allBirthdayItems
        }

        return Array(birthdayService.uniqueBirthdayItems(filteredItems).prefix(5))
    }

    /// ホームのメニューに表示する選択名です。
    var selectedGroupName: String {
        guard let selectedGroupId,
              let group = groups.first(where: { $0.groupId == selectedGroupId }) else {
            return "すべてのグループ"
        }
        return group.name
    }

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
            let loadedGroups = try await groupRepository.fetchUserGroups(userId: userId)
            groups = loadedGroups
            allBirthdayItems = try await loadBirthdayItems(groups: loadedGroups)

            if let selectedGroupId,
               !loadedGroups.contains(where: { $0.groupId == selectedGroupId }) {
                self.selectedGroupId = nil
            }
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }

    func loadBirthdayItems(userId: String) async throws -> [BirthdayDisplayItem] {
        let groups = try await groupRepository.fetchUserGroups(userId: userId)
        return try await loadBirthdayItems(groups: groups)
    }

    /// ホームに表示するグループを切り替えます。nilの場合は全グループを表示します。
    func selectGroup(groupId: String?) {
        selectedGroupId = groupId
    }

    /// 指定されたグループ一覧から、誕生日情報を読み込みます。
    private func loadBirthdayItems(groups: [BirthdayGroup]) async throws -> [BirthdayDisplayItem] {
        var allItems: [BirthdayDisplayItem] = []

        for group in groups {
            let members = try await groupRepository.fetchMembers(groupId: group.groupId)
            var users: [AppUser] = []

            for member in members where member.showBirthday {
                if let user = try? await userRepository.fetchPublicProfile(userId: member.userId) {
                    users.append(user)
                }
            }

            allItems.append(contentsOf: birthdayService.birthdayItems(users: users, members: members, group: group))
        }

        return allItems.sorted {
            if $0.daysUntilBirthday == $1.daysUntilBirthday {
                return $0.user.displayName.localizedStandardCompare($1.user.displayName) == .orderedAscending
            }
            return $0.daysUntilBirthday < $1.daysUntilBirthday
        }
    }
}
