//
//  MainTabView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI

/// Frienday の主要4タブを表示します。
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "calendar.badge.clock")
                }

            GroupListView()
                .tabItem {
                    Label("グループ", systemImage: "person.3")
                }

            BirthdayCalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
