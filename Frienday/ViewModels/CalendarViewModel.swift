//
//  CalendarViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation
import Observation

/// 月間カレンダーに表示する誕生日を管理します。
@Observable
@MainActor
final class CalendarViewModel {
    private let groupRepository: GroupRepository
    private let userRepository: UserRepository
    private let birthdayService: BirthdayCalculationService
    private let calendar: Calendar

    var displayedMonth: Date
    var selectedDate: Date?
    private(set) var items: [BirthdayDisplayItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(
        groupRepository: GroupRepository = GroupRepository(),
        userRepository: UserRepository = UserRepository(),
        birthdayService: BirthdayCalculationService = BirthdayCalculationService(),
        calendar: Calendar = .current
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.birthdayService = birthdayService
        self.calendar = calendar
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            items = birthdayService.uniqueBirthdayItems(try await loadBirthdayItems(userId: userId))
        } catch {
            errorMessage = AppError.map(error).message
        }

        isLoading = false
    }

    func moveMonth(value: Int) {
        if let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = nextMonth
            selectedDate = nil
        }
    }

    func items(on date: Date) -> [BirthdayDisplayItem] {
        let components = calendar.dateComponents([.month, .day], from: date)
        return items.filter {
            $0.user.birthMonth == components.month && birthdayDay(for: $0.user, year: calendar.component(.year, from: date)) == components.day
        }
    }

    func daysForDisplayedMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let leading = calendar.component(.weekday, from: firstDay) - 1
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }

        return Array(repeating: nil, count: leading) + days
    }

    private func birthdayDay(for user: AppUser, year: Int) -> Int {
        if user.birthMonth == 2, user.birthDay == 29 {
            let isLeap = (year.isMultiple(of: 4) && !year.isMultiple(of: 100)) || year.isMultiple(of: 400)
            return isLeap ? 29 : 28
        }
        return user.birthDay
    }

    private func loadBirthdayItems(userId: String) async throws -> [BirthdayDisplayItem] {
        let groups = try await groupRepository.fetchUserGroups(userId: userId)
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

        return allItems
    }
}
