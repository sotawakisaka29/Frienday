//
//  FriendayApp.swift
//  Frienday
//
//  Created by 脇坂颯大 on 22/07/2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct FriendayApp: App {
    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
