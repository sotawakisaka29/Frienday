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
    let onRetry: () -> Void

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 52)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(isCurrentUser ? Color.accentColor : Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 5) {
                    Text(message.displayDate, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    deliveryStatus
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 52)
            }
        }
        .accessibilityElement(children: .combine)
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
    VStack {
        ChatMessageBubble(
            message: ChatMessage(
                messageId: "preview-1",
                senderId: "me",
                text: "また明日ね！",
                deliveryState: .sent
            ),
            isCurrentUser: true,
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
            onRetry: {}
        )
    }
    .padding()
}
