//
//  JapaneseHolidayUtility.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation

/// 日本の祝日・振替休日・国民の休日を判定します。
enum JapaneseHolidayUtility {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    /// 指定日が日本の祝日に当たるかを返します。
    static func isHoliday(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return false
        }

        return holidayKeys(in: year).contains(key(year: year, month: month, day: day))
    }

    /// 指定年の祝日を日付キーの集合として作ります。
    private static func holidayKeys(in year: Int) -> Set<Int> {
        guard (1948...2099).contains(year) else { return [] }

        var holidays = baseHolidayKeys(in: year)
        addCitizensHolidays(year: year, to: &holidays)
        addSubstituteHolidays(year: year, to: &holidays)
        return holidays
    }

    /// 固定日と「第何月曜日」形式の祝日を作ります。
    private static func baseHolidayKeys(in year: Int) -> Set<Int> {
        var holidays: Set<Int> = [
            key(year: year, month: 1, day: 1),
            key(year: year, month: 4, day: 29),
            key(year: year, month: 5, day: 3),
            key(year: year, month: 5, day: 5),
            key(year: year, month: 11, day: 3),
            key(year: year, month: 11, day: 23)
        ]

        if year >= 1949 {
            holidays.insert(key(year: year, month: 1, day: year >= 2000 ? nthWeekday(2, weekday: 2, month: 1, year: year) : 15))
        }

        if year >= 1967 {
            holidays.insert(key(year: year, month: 2, day: 11))
        }

        if year >= 2020 {
            holidays.insert(key(year: year, month: 2, day: 23))
        } else if (1989...2018).contains(year) {
            holidays.insert(key(year: year, month: 12, day: 23))
        }

        if let day = vernalEquinoxDay(year: year) {
            holidays.insert(key(year: year, month: 3, day: day))
        }

        if year >= 2007 {
            holidays.insert(key(year: year, month: 5, day: 4))
        }

        addMarineDay(year: year, to: &holidays)
        addMountainDay(year: year, to: &holidays)

        if year >= 1966 {
            let respectForAgedDay = year >= 2003 ? nthWeekday(3, weekday: 2, month: 9, year: year) : 15
            holidays.insert(key(year: year, month: 9, day: respectForAgedDay))
        }

        if let day = autumnalEquinoxDay(year: year) {
            holidays.insert(key(year: year, month: 9, day: day))
        }

        addSportsDay(year: year, to: &holidays)
        addOneTimeHolidays(year: year, to: &holidays)
        return holidays
    }

    /// 海の日と東京大会年の移動日を追加します。
    private static func addMarineDay(year: Int, to holidays: inout Set<Int>) {
        guard year >= 1996 else { return }

        let day: Int
        switch year {
        case 2020:
            day = 23
        case 2021:
            day = 22
        default:
            day = year >= 2003 ? nthWeekday(3, weekday: 2, month: 7, year: year) : 20
        }
        holidays.insert(key(year: year, month: 7, day: day))
    }

    /// 山の日と東京大会年の移動日を追加します。
    private static func addMountainDay(year: Int, to holidays: inout Set<Int>) {
        guard year >= 2016 else { return }

        let day: Int
        switch year {
        case 2020:
            day = 10
        case 2021:
            day = 8
        default:
            day = 11
        }
        holidays.insert(key(year: year, month: 8, day: day))
    }

    /// スポーツの日と東京大会年の移動日を追加します。
    private static func addSportsDay(year: Int, to holidays: inout Set<Int>) {
        guard year >= 1966 else { return }

        if year == 2020 {
            holidays.insert(key(year: year, month: 7, day: 24))
        } else if year == 2021 {
            holidays.insert(key(year: year, month: 7, day: 23))
        } else {
            let day = year >= 2000 ? nthWeekday(2, weekday: 2, month: 10, year: year) : 10
            holidays.insert(key(year: year, month: 10, day: day))
        }
    }

    /// 即位に伴う特別な祝日を追加します。
    private static func addOneTimeHolidays(year: Int, to holidays: inout Set<Int>) {
        guard year == 2019 else { return }
        [(4, 30), (5, 1), (5, 2), (10, 22)].forEach { month, day in
            holidays.insert(key(year: year, month: month, day: day))
        }
    }

    /// 2つの祝日に挟まれた平日を国民の休日にします。
    private static func addCitizensHolidays(year: Int, to holidays: inout Set<Int>) {
        guard year >= 1986,
              let start = calendar.date(from: DateComponents(year: year, month: 1, day: 2)),
              let end = calendar.date(from: DateComponents(year: year, month: 12, day: 30)) else {
            return
        }

        var date = start
        while date <= end {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date),
                  let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }

            let currentKey = key(for: date)
            let isSunday = calendar.component(.weekday, from: date) == 1
            if !isSunday,
               !holidays.contains(currentKey),
               holidays.contains(key(for: previous)),
               holidays.contains(key(for: next)) {
                holidays.insert(currentKey)
            }

            guard let followingDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = followingDate
        }
    }

    /// 日曜日の祝日に対応する振替休日を追加します。
    private static func addSubstituteHolidays(year: Int, to holidays: inout Set<Int>) {
        guard year >= 1973 else { return }

        let sundayHolidays = holidays.filter { holidayKey in
            guard let date = date(from: holidayKey) else { return false }
            return calendar.component(.weekday, from: date) == 1
        }

        for holidayKey in sundayHolidays {
            guard var substitute = date(from: holidayKey),
                  let followingDate = calendar.date(byAdding: .day, value: 1, to: substitute) else {
                continue
            }
            substitute = followingDate

            if year >= 2007 {
                while holidays.contains(key(for: substitute)) {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: substitute) else { break }
                    substitute = nextDate
                }
            }

            holidays.insert(key(for: substitute))
        }
    }

    /// 指定月の第n曜日の日付を返します。
    private static func nthWeekday(_ ordinal: Int, weekday: Int, month: Int, year: Int) -> Int {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 1 }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        return 1 + (weekday - firstWeekday + 7) % 7 + (ordinal - 1) * 7
    }

    /// 春分の日を天文計算式から返します。
    private static func vernalEquinoxDay(year: Int) -> Int? {
        if (1980...2099).contains(year) {
            return Int(20.8431 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4
        }
        if (1900...1979).contains(year) {
            return Int(20.8357 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4
        }
        return nil
    }

    /// 秋分の日を天文計算式から返します。
    private static func autumnalEquinoxDay(year: Int) -> Int? {
        if (1980...2099).contains(year) {
            return Int(23.2488 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4
        }
        if (1900...1979).contains(year) {
            return Int(23.2588 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4
        }
        return nil
    }

    /// 年月日を比較用の数値に変換します。
    private static func key(year: Int, month: Int, day: Int) -> Int {
        year * 10_000 + month * 100 + day
    }

    /// Dateを比較用の数値に変換します。
    private static func key(for date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return key(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    /// 比較用の数値をDateに戻します。
    private static func date(from key: Int) -> Date? {
        calendar.date(from: DateComponents(year: key / 10_000, month: key / 100 % 100, day: key % 100))
    }
}
