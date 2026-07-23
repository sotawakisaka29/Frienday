//
//  BirthdayCalendarView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// 所属グループ全体の誕生日を月間カレンダーで表示します。
struct BirthdayCalendarView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = CalendarViewModel()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                monthHeader
                weekdayHeader
                calendarGrid(
                    cellHeight: cellHeight(availableHeight: geometry.size.height),
                    labelFontSize: labelFontSize(availableWidth: geometry.size.width)
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
            .overlay {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "読み込めませんでした",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
        }
        .task {
            await load()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("前月")

            Spacer()

            Text(DateUtility.monthTitleFormatter.string(from: viewModel.displayedMonth))
                .font(.title)
                .bold()

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("翌月")
        }
        .padding(.top, 4)
    }

    /// 横方向のスワイプを判定し、前後の月へ移動します。
    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) >= 50,
                      abs(horizontalDistance) > abs(verticalDistance) else {
                    return
                }

                moveMonth(by: horizontalDistance < 0 ? 1 : -1)
            }
    }

    /// ボタンとスワイプから共通で呼び出す月移動処理です。
    private func moveMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.moveMonth(value: value)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { index, weekday in
                Text(weekday)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(weekdayColor(at: index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 曜日見出しの色を日曜と土曜で切り替えます。
    private func weekdayColor(at index: Int) -> Color {
        switch index {
        case 0:
            return .red
        case 6:
            return .blue
        default:
            return .secondary
        }
    }

    private func calendarGrid(cellHeight: CGFloat, labelFontSize: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(viewModel.daysForDisplayedMonth().enumerated()), id: \.offset) { _, date in
                if let date {
                    CalendarDayCell(
                        date: date,
                        items: viewModel.items(on: date),
                        height: cellHeight,
                        labelFontSize: labelFontSize
                    )
                } else {
                    Color.clear
                        .frame(height: cellHeight)
                }
            }
        }
    }

    private func cellHeight(availableHeight: CGFloat) -> CGFloat {
        let dayCount = viewModel.daysForDisplayedMonth().count
        let rowCount = max(1, (dayCount + 6) / 7)
        let gridSpacing = CGFloat(rowCount - 1) * 6
        let headerHeight: CGFloat = 112
        return max(72, (availableHeight - headerHeight - gridSpacing) / CGFloat(rowCount))
    }

    /// 画面幅から1マスの幅を求め、全角7文字が入る共通サイズを返します。
    private func labelFontSize(availableWidth: CGFloat) -> CGFloat {
        let calendarHorizontalPadding: CGFloat = 12
        let totalColumnSpacing: CGFloat = 12
        let labelHorizontalPadding: CGFloat = 6
        let cellWidth = (availableWidth - calendarHorizontalPadding - totalColumnSpacing) / 7
        let availableLabelWidth = max(0, cellWidth - labelHorizontalPadding)
        return min(10, max(4, availableLabelWidth / 7))
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.load(userId: userId)
    }
}

/// カレンダーの1日分のセルです。
struct CalendarDayCell: View {
    let date: Date
    let items: [BirthdayDisplayItem]
    let height: CGFloat
    let labelFontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(dateColor)
                .frame(maxWidth: .infinity)

            ForEach(items.prefix(3)) { item in
                birthdayLabel(item.user.displayName, colorHex: item.user.imageColorHex)
            }

            if items.count > 3 {
                Text("ほか\(items.count - 3)人")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("\(Calendar.current.component(.day, from: date))日、誕生日\(items.count)件")
    }

    /// 誕生日の人の表示名を、1行のラベルとして表示します。
    private func birthdayLabel(_ displayName: String, colorHex: String) -> some View {
        Text(displayName)
            .font(.system(size: labelFontSize, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 1)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .background(Color(profileHex: colorHex), in: RoundedRectangle(cornerRadius: 4))
    }

    /// 日曜日と祝日は赤、土曜日は青、平日は標準色を返します。
    private var dateColor: Color {
        let weekday = Calendar.current.component(.weekday, from: date)

        if weekday == 1 || JapaneseHolidayUtility.isHoliday(date) {
            return .red
        }
        if weekday == 7 {
            return .blue
        }
        return .primary
    }
}

#Preview {
    BirthdayCalendarView()
        .environment(AuthViewModel())
}
