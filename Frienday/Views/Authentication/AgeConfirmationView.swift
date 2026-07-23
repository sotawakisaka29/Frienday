//
//  AgeConfirmationView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI

/// 初回起動時に利用者が13歳以上かを確認する画面です。
struct AgeConfirmationView: View {
    let onConfirmed: () -> Void

    @State private var showsAgeRestriction = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("年齢の確認")
                .font(.largeTitle.bold())
                .padding(.top, 24)

            Text("Friendayを利用するには、13歳以上である必要があります。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text("あなたは13歳以上ですか？")
                .font(.title3.bold())
                .padding(.top, 32)

            if showsAgeRestriction {
                Label(
                    "申し訳ありません。13歳未満の方はFriendayを利用できません。",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .accessibilityLabel("13歳未満の方はFriendayを利用できません")
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onConfirmed()
                } label: {
                    Text("はい、13歳以上です")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button("いいえ、13歳未満です") {
                    withAnimation {
                        showsAgeRestriction = true
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

#Preview {
    AgeConfirmationView(onConfirmed: {})
}
