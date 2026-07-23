//
//  DirectChatView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI
import FirebaseAuth

/// 1対1のリアルタイムチャットと安全機能を表示します。
struct DirectChatView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: DirectChatViewModel
    @State private var networkMonitor = NetworkStatusMonitor()
    @State private var messageToDelete: ChatMessage?
    @State private var messageToReport: ChatMessage?
    @State private var showsBlockConfirmation = false

    init(contact: ChatContact) {
        _viewModel = State(initialValue: DirectChatViewModel(contact: contact))
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBanners
            messageList

            if viewModel.isBlocked {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("ブロック中です。解除すると送信できます。")
                }
                .font(.callout)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
            } else if !viewModel.isChatAvailable {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                        Text("チャットを準備しています…")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("チャットを利用できません。前の画面に戻って再度お試しください。")
                    }
                }
                .font(.callout)
                .foregroundStyle(viewModel.isLoading ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
            } else {
                ChatComposerView(
                    text: draftBinding,
                    isEnabled: viewModel.canSend,
                    onTextChange: viewModel.updateDraft,
                    onSend: {
                        Task { await viewModel.send(isConnected: networkMonitor.isConnected) }
                    }
                )
            }
        }
        .navigationTitle(viewModel.contact.user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: viewModel.isBlocked ? nil : .destructive) {
                        showsBlockConfirmation = true
                    } label: {
                        Label(
                            viewModel.isBlocked ? "ブロックを解除" : "この相手をブロック",
                            systemImage: viewModel.isBlocked ? "hand.raised.slash" : "hand.raised"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            guard let userId = authViewModel.currentUser?.uid else { return }
            await viewModel.start(userId: userId)
        }
        .onDisappear {
            viewModel.stop()
        }
        .confirmationDialog(
            "このメッセージを削除しますか？",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                guard let messageToDelete else { return }
                Task { await viewModel.delete(messageToDelete) }
                self.messageToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                messageToDelete = nil
            }
        }
        .confirmationDialog(
            "通報する理由を選んでください",
            isPresented: reportConfirmationBinding,
            titleVisibility: .visible
        ) {
            ForEach(ChatReportReason.allCases) { reason in
                Button(reason.label) {
                    guard let messageToReport else { return }
                    Task { await viewModel.report(messageToReport, reason: reason) }
                    self.messageToReport = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                messageToReport = nil
            }
        }
        .confirmationDialog(
            viewModel.isBlocked ? "ブロックを解除しますか？" : "この相手をブロックしますか？",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                viewModel.isBlocked ? "解除" : "ブロック",
                role: viewModel.isBlocked ? nil : .destructive
            ) {
                Task { await viewModel.toggleBlock() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if !viewModel.isBlocked {
                Text("お互いに新しいメッセージを送れなくなります。")
            }
        }
    }

    @ViewBuilder
    private var statusBanners: some View {
        if !networkMonitor.isConnected {
            Label("オフラインです。送信すると失敗として表示されます。", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.orange)
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.08))
        } else if let successMessage = viewModel.successMessage {
            Text(successMessage)
                .font(.caption)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 7)
                .background(Color.green.opacity(0.08))
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if viewModel.messages.isEmpty {
                        ContentUnavailableView(
                            "まだメッセージがありません",
                            systemImage: "message",
                            description: Text("最初のメッセージを送ってみましょう。")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.messageId)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.messages.count) {
                guard let lastMessage = viewModel.messages.last else { return }
                withAnimation {
                    proxy.scrollTo(lastMessage.messageId, anchor: .bottom)
                }
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isCurrentUser = message.senderId == authViewModel.currentUser?.uid

        return ChatMessageBubble(
            message: message,
            isCurrentUser: isCurrentUser,
            onRetry: {
                Task {
                    await viewModel.retry(message, isConnected: networkMonitor.isConnected)
                }
            }
        )
        .contextMenu {
            if isCurrentUser {
                Button(role: .destructive) {
                    messageToDelete = message
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else if message.deliveryState == .sent {
                Button(role: .destructive) {
                    messageToReport = message
                } label: {
                    Label("通報", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    private var draftBinding: Binding<String> {
        Binding {
            viewModel.draft
        } set: { value in
            viewModel.updateDraft(value)
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            messageToDelete != nil
        } set: { isPresented in
            if !isPresented {
                messageToDelete = nil
            }
        }
    }

    private var reportConfirmationBinding: Binding<Bool> {
        Binding {
            messageToReport != nil
        } set: { isPresented in
            if !isPresented {
                messageToReport = nil
            }
        }
    }
}

#Preview {
    let user = AppUser(
        userId: "friend",
        displayName: "友達",
        email: "",
        birthYear: 0,
        birthMonth: 4,
        birthDay: 1
    )
    let connection = ChatConnection(
        userId: "me",
        otherUserId: "friend",
        activeGroupId: "group"
    )

    NavigationStack {
        DirectChatView(
            contact: ChatContact(
                connection: connection,
                user: user,
                isBlocked: false
            )
        )
        .environment(AuthViewModel())
    }
}
