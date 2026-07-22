//
//  ContentView.swift
//  Frienday
//
//  Created by 脇坂颯大 on 22/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var authViewModel = AuthViewModel()

    var body: some View {
        RootView()
            .environment(authViewModel)
    }
}

#Preview {
    ContentView()
}
