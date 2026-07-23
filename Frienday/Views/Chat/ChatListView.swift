//
//  ChatListView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI
import FirebaseAuth

/// 共通グループがあり、個人チャットできる相手を一覧表示します。
struct ChatListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isSynchronizing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("グループのつながりを確認中...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("チャットできる友達") {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.contacts.isEmpty {
                        ContentUnavailableView(
                            "チャットできる友達がいません",
                            systemImage: "message",
                            description: Text("同じグループに参加している友達が表示されます。")
                        )
                    } else {
                        ForEach(viewModel.contacts) { contact in
                            NavigationLink(value: contact) {
                                ChatContactRow(contact: contact)
                            }
                        }
                    }
                }
            }
            .navigationTitle("チャット")
            .navigationDestination(for: ChatContact.self) { contact in
                DirectChatView(contact: contact)
            }
            .refreshable {
                await refresh()
            }
            .task {
                await load()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.load(userId: userId)
        await viewModel.configurePushNotifications(userId: userId)
    }

    private func refresh() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.refresh(userId: userId)
    }
}

/// チャット相手のプロフィールとブロック状態を表示します。
private struct ChatContactRow: View {
    let contact: ChatContact

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(user: contact.user, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.user.displayName)
                    .font(.headline)

                if contact.isBlocked {
                    Label("ブロック中", systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("個人チャット")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ChatListView()
        .environment(AuthViewModel())
}
