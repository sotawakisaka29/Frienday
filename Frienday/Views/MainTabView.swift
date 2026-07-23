//
//  MainTabView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI

/// Frienday の主要5タブを表示します。
struct MainTabView: View {
    @State private var selectedTab = MainTab.home
    @State private var pendingTab: MainTab?
    @State private var showsUnsavedProfileConfirmation = false
    @State private var settingsViewModel = SettingsViewModel()

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "calendar.badge.clock")
                }
                .tag(MainTab.home)

            GroupListView()
                .tabItem {
                    Label("グループ", systemImage: "person.3")
                }
                .tag(MainTab.groups)

            ChatListView()
                .tabItem {
                    Label("チャット", systemImage: "message")
                }
                .tag(MainTab.chat)

            BirthdayCalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(MainTab.calendar)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(MainTab.settings)
        }
        .confirmationDialog(
            "プロフィールの変更を保存せずに移動しますか？",
            isPresented: $showsUnsavedProfileConfirmation,
            titleVisibility: .visible
        ) {
            Button("保存せずに移動", role: .destructive) {
                moveWithoutSaving()
            }
            Button("キャンセル", role: .cancel) {
                pendingTab = nil
            }
        } message: {
            Text("入力したプロフィール情報は失われます。")
        }
    }

    private var tabSelection: Binding<MainTab> {
        Binding {
            selectedTab
        } set: { newTab in
            guard newTab != selectedTab else { return }

            if selectedTab == .settings,
               settingsViewModel.hasProfileChanges,
               !settingsViewModel.isSavingProfile {
                pendingTab = newTab
                showsUnsavedProfileConfirmation = true
            } else {
                selectedTab = newTab
            }
        }
    }

    /// 未保存のプロフィール変更を取り消して、選択されたタブへ移動します。
    private func moveWithoutSaving() {
        guard let pendingTab else { return }
        settingsViewModel.discardProfileChanges()
        selectedTab = pendingTab
        self.pendingTab = nil
    }
}

/// メイン画面に表示するタブを表します。
private enum MainTab: Hashable {
    case home
    case groups
    case chat
    case calendar
    case settings
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
