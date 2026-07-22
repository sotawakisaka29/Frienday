//
//  BirthdayCalculationService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// 誕生日の日付計算を担当します。
struct BirthdayCalculationService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func nextBirthday(month: Int, day: Int, from date: Date = Date()) -> Date {
        let todayStart = calendar.startOfDay(for: date)
        let currentYear = calendar.component(.year, from: todayStart)

        if let birthdayThisYear = birthdayDate(year: currentYear, month: month, day: day),
           birthdayThisYear >= todayStart {
            return birthdayThisYear
        }

        return birthdayDate(year: currentYear + 1, month: month, day: day) ?? todayStart
    }

    func daysUntilBirthday(month: Int, day: Int, from date: Date = Date()) -> Int {
        let todayStart = calendar.startOfDay(for: date)
        let next = nextBirthday(month: month, day: day, from: todayStart)
        return calendar.dateComponents([.day], from: todayStart, to: next).day ?? 0
    }

    func birthdayItems(users: [AppUser], members: [GroupMember], group: BirthdayGroup, from date: Date = Date()) -> [BirthdayDisplayItem] {
        members.compactMap { member in
            guard member.showBirthday,
                  let user = users.first(where: { $0.userId == member.userId }) else {
                return nil
            }

            let nextBirthday = nextBirthday(month: user.birthMonth, day: user.birthDay, from: date)
            let days = daysUntilBirthday(month: user.birthMonth, day: user.birthDay, from: date)
            return BirthdayDisplayItem(user: user, group: group, member: member, nextBirthday: nextBirthday, daysUntilBirthday: days)
        }
        .sorted {
            if $0.daysUntilBirthday == $1.daysUntilBirthday {
                return $0.user.displayName.localizedStandardCompare($1.user.displayName) == .orderedAscending
            }
            return $0.daysUntilBirthday < $1.daysUntilBirthday
        }
    }

    func uniqueBirthdayItems(_ items: [BirthdayDisplayItem]) -> [BirthdayDisplayItem] {
        var seenUserIds = Set<String>()
        var uniqueItems: [BirthdayDisplayItem] = []

        for item in items {
            guard !seenUserIds.contains(item.user.userId) else { continue }
            seenUserIds.insert(item.user.userId)
            uniqueItems.append(item)
        }

        return uniqueItems
    }

    private func birthdayDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = adjustedDay(year: year, month: month, day: day)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private func adjustedDay(year: Int, month: Int, day: Int) -> Int {
        if month == 2, day == 29, !isLeapYear(year) {
            return 28
        }
        return day
    }

    private func isLeapYear(_ year: Int) -> Bool {
        (year.isMultiple(of: 4) && !year.isMultiple(of: 100)) || year.isMultiple(of: 400)
    }
}
