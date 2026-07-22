//
//  RootView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI

/// ログイン状態に応じて認証画面とメイン画面を切り替えます。
struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if authViewModel.isCheckingSession {
                ProgressView("確認中...")
            } else if authViewModel.isSignedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AuthViewModel())
}
