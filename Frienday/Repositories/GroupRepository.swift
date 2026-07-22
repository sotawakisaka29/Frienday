//
//  GroupRepository.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// グループ関連の操作を ViewModel に提供します。
struct GroupRepository {
    private let groupService: GroupService

    init(groupService: GroupService = GroupService()) {
        self.groupService = groupService
    }

    func createGroup(name: String, ownerId: String) async throws -> BirthdayGroup {
        try await groupService.createGroup(name: name, ownerId: ownerId)
    }

    func joinGroup(inviteCode: String, userId: String) async throws {
        try await groupService.joinGroup(inviteCode: inviteCode, userId: userId)
    }

    func fetchUserGroups(userId: String) async throws -> [BirthdayGroup] {
        try await groupService.fetchUserGroups(userId: userId)
    }

    func fetchMembers(groupId: String) async throws -> [GroupMember] {
        try await groupService.fetchMembers(groupId: groupId)
    }

    func updateMemberSettings(
        groupId: String,
        userId: String,
        showBirthday: Bool,
        showBirthYear: Bool,
        sharedBirthYear: Int?
    ) async throws {
        try await groupService.updateMemberSettings(
            groupId: groupId,
            userId: userId,
            showBirthday: showBirthday,
            showBirthYear: showBirthYear,
            sharedBirthYear: sharedBirthYear
        )
    }

    func leaveGroup(group: BirthdayGroup, userId: String) async throws {
        try await groupService.leaveGroup(group: group, userId: userId)
    }

    func deleteGroup(group: BirthdayGroup, requesterId: String) async throws {
        try await groupService.deleteGroup(group: group, requesterId: requesterId)
    }
}
