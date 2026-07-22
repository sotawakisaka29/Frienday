//
//  HomeView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// 直近5人の誕生日を、近い順に表示します。
struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("読み込めませんでした", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ScrollView {
                        birthdayContent
                            .padding()
                    }
                    .refreshable {
                        await load()
                    }
                }
            }
            .navigationTitle("ホーム")
            .toolbar {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("再読み込み")
            }
            .task {
                await load()
            }
        }
    }

    private var birthdayContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            groupSelector

            Text(DateUtility.fullDateFormatter.string(from: Date()))
                .font(.headline)
                .foregroundStyle(.secondary)

            if let firstItem = viewModel.upcomingItems.first {
                FeaturedBirthdayView(item: firstItem)

                let remainingItems = Array(viewModel.upcomingItems.dropFirst())
                if !remainingItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("このあとの誕生日")
                            .font(.headline)

                        VStack(spacing: 0) {
                            ForEach(remainingItems) { item in
                                CompactBirthdayRow(item: item)

                                if item.id != remainingItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("まだ誕生日がありません", systemImage: "gift", description: Text(emptyDescription))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 「すべて」または所属グループを選ぶメニューです。
    private var groupSelector: some View {
        Menu {
            Button {
                viewModel.selectGroup(groupId: nil)
            } label: {
                Label("すべてのグループ", systemImage: viewModel.selectedGroupId == nil ? "checkmark" : "person.3")
            }

            if !viewModel.groups.isEmpty {
                Divider()
            }

            ForEach(viewModel.groups) { group in
                Button {
                    viewModel.selectGroup(groupId: group.groupId)
                } label: {
                    Label(group.name, systemImage: viewModel.selectedGroupId == group.groupId ? "checkmark" : "person.3")
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.3")
                Text(viewModel.selectedGroupName)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("表示中のグループ、\(viewModel.selectedGroupName)")
    }

    /// 選択している表示範囲に合わせた空表示の説明です。
    private var emptyDescription: String {
        if viewModel.selectedGroupId == nil {
            return "グループを作成するか、招待コードで参加してください。"
        }
        return "このグループには表示できる誕生日がまだありません。"
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.load(userId: userId)
    }
}

/// 最も近い誕生日を大きく表示します。
private struct FeaturedBirthdayView: View {
    let item: BirthdayDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("いちばん近い誕生日", systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Spacer()
                Text(daysText)
                    .font(.headline)
            }

            Spacer(minLength: 4)

            Text(item.user.displayName)
                .font(.system(size: 38, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text("\(DateUtility.monthDayFormatter.string(from: item.nextBirthday))の誕生日")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(item.group.name)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("いちばん近い誕生日、\(item.user.displayName)さん、\(DateUtility.monthDayFormatter.string(from: item.nextBirthday))、\(daysText)、\(item.group.name)")
    }

    private var daysText: String {
        item.daysUntilBirthday == 0 ? "今日" : "あと\(item.daysUntilBirthday)日"
    }
}

/// 2人目以降の誕生日をコンパクトに表示します。
private struct CompactBirthdayRow: View {
    let item: BirthdayDisplayItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.user.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(DateUtility.monthDayFormatter.string(from: item.nextBirthday)) ・ \(item.group.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(item.daysUntilBirthday == 0 ? "今日" : "あと\(item.daysUntilBirthday)日")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.daysUntilBirthday == 0 ? Color.accentColor : Color.primary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.user.displayName)さん、\(DateUtility.monthDayFormatter.string(from: item.nextBirthday))、あと\(item.daysUntilBirthday)日、\(item.group.name)")
    }
}

#Preview {
    HomeView()
        .environment(AuthViewModel())
}
