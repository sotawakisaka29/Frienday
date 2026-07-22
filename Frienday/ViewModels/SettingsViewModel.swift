//
//  SettingsViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import Observation

/// 設定画面のプロフィール、通知、アカウント操作を管理します。
@Observable
@MainActor
final class SettingsViewModel {
    private let userRepository: UserRepository
    private let groupRepository: GroupRepository
    private let notificationService: NotificationService

    private(set) var profile: AppUser?
    var profileDisplayName = ""
    var profileBirthday = Date()
    private(set) var hasProfileChanges = false
    var notificationSettings: NotificationSettings
    private(set) var savedNotificationSettings: NotificationSettings
    private(set) var isLoading = false
    private(set) var isSavingProfile = false
    private(set) var isUpdatingNotifications = false
    private(set) var errorMessage: String?
    private(set) var successMessage: String?

    init(
        userRepository: UserRepository = UserRepository(),
        groupRepository: GroupRepository = GroupRepository(),
        notificationService: NotificationService = NotificationService()
    ) {
        self.userRepository = userRepository
        self.groupRepository = groupRepository
        self.notificationService = notificationService
        let notificationSettings = notificationService.loadSettings()
        self.notificationSettings = notificationSettings
        savedNotificationSettings = notificationSettings
    }

    var hasNotificationChanges: Bool {
        notificationSettings != savedNotificationSettings
    }

    /// 表示名の入力を反映し、保存済みデータとの差を更新します。
    func setProfileDisplayName(_ displayName: String) {
        profileDisplayName = displayName
        updateProfileChangeState()
        clearFeedback()
    }

    /// 生年月日の入力を反映し、保存済みデータとの差を更新します。
    func setProfileBirthday(_ birthday: Date) {
        profileBirthday = birthday
        updateProfileChangeState()
        clearFeedback()
    }

    /// 通知全体のオン・オフを編集中の設定へ反映します。
    func setNotificationsEnabled(_ isEnabled: Bool) {
        var settings = notificationSettings
        settings.isEnabled = isEnabled
        notificationSettings = settings
        clearFeedback()
    }

    /// 当日通知の変更を編集中の設定へ反映します。
    func setNotifyOnDay(_ isEnabled: Bool) {
        var settings = notificationSettings
        settings.notifyOnDay = isEnabled
        notificationSettings = settings
        clearFeedback()
    }

    /// 前日通知の変更を編集中の設定へ反映します。
    func setNotifyDayBefore(_ isEnabled: Bool) {
        var settings = notificationSettings
        settings.notifyDayBefore = isEnabled
        notificationSettings = settings
        clearFeedback()
    }

    /// 通知時刻の変更を編集中の設定へ反映します。
    func setNotificationTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        var settings = notificationSettings
        settings.notificationHour = components.hour ?? 9
        settings.notificationMinute = components.minute ?? 0
        notificationSettings = settings
        clearFeedback()
    }

    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile = try await userRepository.fetchProfile(userId: userId)
            self.profile = profile
            profileDisplayName = profile.displayName

            var components = DateComponents()
            components.year = profile.birthYear
            components.month = profile.birthMonth
            components.day = profile.birthDay
            profileBirthday = Calendar.current.date(from: components) ?? Date()
            hasProfileChanges = false
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }

    func updateProfile() async {
        guard var profile else {
            errorMessage = AppError.profileNotLoaded.message
            return
        }
        isSavingProfile = true
        successMessage = nil
        defer { isSavingProfile = false }

        do {
            let components = try ValidationUtility.validateBirthday(profileBirthday)
            guard let year = components.year, let month = components.month, let day = components.day else {
                throw AppError.invalidBirthday
            }

            profile.displayName = try ValidationUtility.validateDisplayName(profileDisplayName)
            profile.birthYear = year
            profile.birthMonth = month
            profile.birthDay = day
            try await userRepository.updateProfile(profile)
            self.profile = profile
            profileDisplayName = profile.displayName
            hasProfileChanges = false
            successMessage = "プロフィールを更新しました。"
            errorMessage = nil
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    func updateNotifications(items: [BirthdayDisplayItem]) async {
        isUpdatingNotifications = true
        successMessage = nil
        defer { isUpdatingNotifications = false }

        do {
            try await notificationService.registerBirthdayNotifications(items: items, settings: notificationSettings)
            try notificationService.saveSettings(notificationSettings)
            savedNotificationSettings = notificationSettings
            successMessage = notificationSettings.isEnabled ? "通知を登録しました。" : "通知をオフにしました。"
            errorMessage = nil
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    func clearNotifications() {
        notificationService.clearSettings()
        notificationSettings = .default
        savedNotificationSettings = .default
    }

    /// 編集を始めたときに、以前の完了メッセージを消します。
    func clearFeedback() {
        successMessage = nil
        errorMessage = nil
    }

    private func updateProfileChangeState() {
        guard let profile else {
            hasProfileChanges = true
            return
        }

        let normalizedName = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: profileBirthday)
        hasProfileChanges = normalizedName != profile.displayName
            || components.year != profile.birthYear
            || components.month != profile.birthMonth
            || components.day != profile.birthDay
    }

    func deleteAccount(userId: String, authViewModel: AuthViewModel) async {
        isLoading = true
        errorMessage = nil

        do {
            let groups = try await groupRepository.fetchUserGroups(userId: userId)
            for group in groups {
                try await groupRepository.leaveGroup(group: group, userId: userId)
            }
            try await userRepository.deleteProfile(userId: userId)
            notificationService.clearSettings()
            try await authViewModel.deleteAuthAccount()
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }
}
