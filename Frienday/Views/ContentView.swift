//
//  ContentView.swift
//  Frienday
//
//  Created by 脇坂颯大 on 22/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var authViewModel = AuthViewModel()
    @AppStorage("hasConfirmedMinimumAge") private var hasConfirmedMinimumAge = false

    var body: some View {
        Group {
            if hasConfirmedMinimumAge {
                RootView()
                    .environment(authViewModel)
            } else {
                AgeConfirmationView {
                    hasConfirmedMinimumAge = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
