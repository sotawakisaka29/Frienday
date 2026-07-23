//
//  ChatMessageBubble.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI

/// 本文、送信日時、通信状態を吹き出しとして表示します。
struct ChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let otherUser: AppUser
    let showsTime: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 52)
            } else {
                ProfileAvatarView(user: otherUser, size: 34)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(isCurrentUser ? Color.accentColor : Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if showsTime || showsDeliveryStatus {
                    HStack(spacing: 5) {
                        if showsTime {
                            Text(message.displayDate, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        deliveryStatus
                    }
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 52)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var showsDeliveryStatus: Bool {
        isCurrentUser && message.deliveryState != .sent
    }

    @ViewBuilder
    private var deliveryStatus: some View {
        if isCurrentUser {
            switch message.deliveryState {
            case .sending:
                HStack(spacing: 3) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("送信中")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            case .delayed:
                Label("通信に時間がかかっています", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            case .failed:
                Button(action: onRetry) {
                    Label("送信できませんでした・再送", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            case .sent:
                EmptyView()
            }
        }
    }
}

#Preview {
    let friend = AppUser(
        userId: "friend",
        displayName: "友達",
        email: "",
        birthYear: 2000,
        birthMonth: 1,
        birthDay: 1
    )

    VStack {
        ChatMessageBubble(
            message: ChatMessage(
                messageId: "preview-1",
                senderId: "me",
                text: "また明日ね！",
                deliveryState: .sent
            ),
            isCurrentUser: true,
            otherUser: friend,
            showsTime: true,
            onRetry: {}
        )

        ChatMessageBubble(
            message: ChatMessage(
                messageId: "preview-2",
                senderId: "friend",
                text: "うん、また明日！",
                deliveryState: .sent
            ),
            isCurrentUser: false,
            otherUser: friend,
            showsTime: true,
            onRetry: {}
        )
    }
    .padding()
}
