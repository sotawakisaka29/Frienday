//
//  BirthdayPicker.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI

/// 西暦・月・日をそれぞれホイールで選択する生年月日ピッカーです。
struct BirthdayPicker: View {
    @Binding var selection: Date

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            Picker("西暦", selection: yearBinding) {
                ForEach(yearValues, id: \.self) { year in
                    Text("\(year)年").tag(year)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("西暦")

            Picker("月", selection: monthBinding) {
                ForEach(monthValues, id: \.self) { month in
                    Text("\(month)月").tag(month)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("月")

            Picker("日", selection: dayBinding) {
                ForEach(dayValues, id: \.self) { day in
                    Text("\(day)日").tag(day)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("日")
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
        .clipped()
    }

    private var selectedComponents: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: selection)
    }

    private var currentComponents: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: Date())
    }

    private var yearValues: [Int] {
        let currentYear = currentComponents.year ?? 2000
        let selectedYear = selectedComponents.year ?? currentYear
        let firstYear = min(currentYear - 120, selectedYear)
        return Array(firstYear...currentYear)
    }

    private var monthValues: [Int] {
        let selectedYear = selectedComponents.year ?? currentComponents.year ?? 2000
        let maximumMonth = selectedYear == currentComponents.year ? currentComponents.month ?? 12 : 12
        return Array(1...maximumMonth)
    }

    private var dayValues: [Int] {
        let year = selectedComponents.year ?? currentComponents.year ?? 2000
        let month = selectedComponents.month ?? 1
        let monthMaximumDay = maximumDay(year: year, month: month)
        let maximumDay = year == currentComponents.year && month == currentComponents.month
            ? min(monthMaximumDay, currentComponents.day ?? monthMaximumDay)
            : monthMaximumDay
        return Array(1...maximumDay)
    }

    private var yearBinding: Binding<Int> {
        Binding {
            selectedComponents.year ?? currentComponents.year ?? 2000
        } set: { year in
            updateSelection(year: year)
        }
    }

    private var monthBinding: Binding<Int> {
        Binding {
            selectedComponents.month ?? 1
        } set: { month in
            updateSelection(month: month)
        }
    }

    private var dayBinding: Binding<Int> {
        Binding {
            selectedComponents.day ?? 1
        } set: { day in
            updateSelection(day: day)
        }
    }

    private func updateSelection(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let currentYear = currentComponents.year ?? 2000
        let currentMonth = currentComponents.month ?? 12
        let currentDay = currentComponents.day ?? 31
        let nextYear = min(year ?? selectedComponents.year ?? currentYear, currentYear)
        let allowedMonth = nextYear == currentYear ? currentMonth : 12
        let nextMonth = min(month ?? selectedComponents.month ?? 1, allowedMonth)
        let monthMaximumDay = maximumDay(year: nextYear, month: nextMonth)
        let allowedDay = nextYear == currentYear && nextMonth == currentMonth
            ? min(monthMaximumDay, currentDay)
            : monthMaximumDay
        let nextDay = min(day ?? selectedComponents.day ?? 1, allowedDay)

        var components = DateComponents()
        components.year = nextYear
        components.month = nextMonth
        components.day = nextDay

        if let date = calendar.date(from: components) {
            selection = date
        }
    }

    private func maximumDay(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 28
        }
        return range.count
    }
}

#Preview {
    @Previewable @State var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    BirthdayPicker(selection: $birthday)
        .padding()
}
