//
//  ChatComposerView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI

/// 50文字までの本文入力と送信ボタンを表示します。
struct ChatComposerView: View {
    @Binding var text: String
    let isEnabled: Bool
    let onTextChange: (String) -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("メッセージ", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, newValue in
                        onTextChange(newValue)
                    }
                    .submitLabel(.send)
                    .onSubmit {
                        guard isEnabled else { return }
                        onSend()
                    }

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(!isEnabled)
                .accessibilityLabel("送信")
            }

            HStack {
                Spacer()
                Text("\(text.count)/50")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(text.count == 50 ? .orange : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

#Preview {
    ChatComposerView(
        text: .constant("こんにちは"),
        isEnabled: true,
        onTextChange: { _ in },
        onSend: {}
    )
}
