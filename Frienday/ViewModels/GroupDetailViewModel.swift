//
//  GroupDetailViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import Observation

/// グループ詳細画面のメンバー一覧と退会・削除を管理します。
@Observable
@MainActor
final class GroupDetailViewModel {
    private let groupRepository: GroupRepository
    private let userRepository: UserRepository
    private let birthdayService: BirthdayCalculationService
    private let widgetSyncService: WidgetBirthdaySyncService

    let group: BirthdayGroup
    private(set) var memberProfiles: [GroupMemberProfile] = []
    private(set) var currentMember: GroupMember?
    private var currentUserBirthYear: Int?
    private(set) var showsBirthYear = false
    private(set) var isLoading = false
    private(set) var isUpdatingPrivacy = false
    private(set) var errorMessage: String?

    var isCurrentUserOwner: Bool {
        currentMember?.role == .owner
    }

    init(
        group: BirthdayGroup,
        groupRepository: GroupRepository = GroupRepository(),
        userRepository: UserRepository = UserRepository(),
        birthdayService: BirthdayCalculationService = BirthdayCalculationService(),
        widgetSyncService: WidgetBirthdaySyncService? = nil
    ) {
        self.group = group
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.birthdayService = birthdayService
        self.widgetSyncService = widgetSyncService ?? WidgetBirthdaySyncService()
    }

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let members = try await groupRepository.fetchMembers(groupId: group.groupId)
            currentMember = members.first(where: { $0.userId == userId })
            showsBirthYear = currentMember?.showBirthYear ?? false
            currentUserBirthYear = (try? await userRepository.fetchProfile(userId: userId))?.birthYear
            var profiles: [GroupMemberProfile] = []

            for member in members {
                if let user = try? await userRepository.fetchPublicProfile(userId: member.userId) {
                    let nextBirthday: Date?
                    let daysUntilBirthday: Int?

                    if member.showBirthday {
                        nextBirthday = birthdayService.nextBirthday(
                            month: user.birthMonth,
                            day: user.birthDay
                        )
                        daysUntilBirthday = birthdayService.daysUntilBirthday(
                            month: user.birthMonth,
                            day: user.birthDay
                        )
                    } else {
                        nextBirthday = nil
                        daysUntilBirthday = nil
                    }

                    profiles.append(
                        GroupMemberProfile(
                            user: user,
                            member: member,
                            group: group,
                            nextBirthday: nextBirthday,
                            daysUntilBirthday: daysUntilBirthday
                        )
                    )
                }
            }

            memberProfiles = profiles.sorted {
                if $0.member.role != $1.member.role {
                    return $0.member.role == .owner
                }
                return $0.user.displayName.localizedStandardCompare($1.user.displayName) == .orderedAscending
            }
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }

    /// このグループで自分の生まれた年を公開するか更新します。
    func updateBirthYearVisibility(_ isVisible: Bool, userId: String) async {
        guard var member = currentMember else {
            errorMessage = AppError.groupNotFound.message
            return
        }

        let previousValue = showsBirthYear
        guard !isVisible || currentUserBirthYear != nil else {
            errorMessage = AppError.profileNotLoaded.message
            return
        }
        showsBirthYear = isVisible
        isUpdatingPrivacy = true
        errorMessage = nil

        do {
            try await groupRepository.updateMemberSettings(
                groupId: group.groupId,
                userId: userId,
                showBirthday: member.showBirthday,
                showBirthYear: isVisible,
                sharedBirthYear: isVisible ? currentUserBirthYear : nil
            )
            member.showBirthYear = isVisible
            member.sharedBirthYear = isVisible ? currentUserBirthYear : nil
            currentMember = member
            updateDisplayedMember(member)
        } catch {
            showsBirthYear = previousValue
            errorMessage = AppError.map(error).message
        }

        isUpdatingPrivacy = false
    }

    func leave(userId: String) async -> Bool {
        do {
            try await groupRepository.leaveGroup(group: group, userId: userId)
            try? await widgetSyncService.refresh(userId: userId)
            return true
        } catch {
            errorMessage = AppError.map(error).message
            return false
        }
    }

    func delete(userId: String) async -> Bool {
        guard isCurrentUserOwner, group.ownerId == userId else {
            errorMessage = AppError.permissionDenied.message
            return false
        }

        do {
            try await groupRepository.deleteGroup(group: group, requesterId: userId)
            try? await widgetSyncService.refresh(userId: userId)
            return true
        } catch {
            errorMessage = AppError.map(error).message
            return false
        }
    }

    private func updateDisplayedMember(_ member: GroupMember) {
        memberProfiles = memberProfiles.map { profile in
            guard profile.member.userId == member.userId else { return profile }
            return GroupMemberProfile(
                user: profile.user,
                member: member,
                group: profile.group,
                nextBirthday: profile.nextBirthday,
                daysUntilBirthday: profile.daysUntilBirthday
            )
        }
    }
}
