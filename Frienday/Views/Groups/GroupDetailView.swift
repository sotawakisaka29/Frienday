//
//  GroupDetailView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// グループの招待コードとメンバー一覧を表示します。
struct GroupDetailView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GroupDetailViewModel
    @State private var showsDeleteConfirmation = false

    init(group: BirthdayGroup) {
        _viewModel = State(initialValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        List {
            Section("招待コード") {
                Text(viewModel.group.inviteCode)
                    .font(.title2.monospaced())
                    .textSelection(.enabled)
                    .accessibilityLabel("招待コード \(viewModel.group.inviteCode)")
            }

            if viewModel.currentMember != nil {
                Section {
                    Toggle("生まれた年を公開", isOn: birthYearVisibilityBinding)
                        .disabled(viewModel.isUpdatingPrivacy)
                } header: {
                    Text("このグループでの公開設定")
                } footer: {
                    Text("オフにすると、誕生日は月と日だけ表示されます。")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("メンバー") {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.memberProfiles.isEmpty {
                    ContentUnavailableView("メンバーを読み込めません", systemImage: "person")
                } else {
                    ForEach(viewModel.memberProfiles) { profile in
                        NavigationLink {
                            GroupMemberProfileView(profile: profile)
                        } label: {
                            GroupMemberRow(profile: profile)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await leaveGroup() }
                } label: {
                    Label("グループから退会", systemImage: "rectangle.portrait.and.arrow.right")
                }

                if viewModel.isCurrentUserOwner {
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("グループを削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(viewModel.group.name)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .confirmationDialog("グループを削除しますか？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task { await deleteGroup() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var birthYearVisibilityBinding: Binding<Bool> {
        Binding {
            viewModel.showsBirthYear
        } set: { isVisible in
            guard let userId = authViewModel.currentUser?.uid else { return }
            Task {
                await viewModel.updateBirthYearVisibility(isVisible, userId: userId)
            }
        }
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.load(userId: userId)
    }

    private func leaveGroup() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        if await viewModel.leave(userId: userId) {
            dismiss()
        }
    }

    private func deleteGroup() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        if await viewModel.delete(userId: userId) {
            dismiss()
        }
    }
}

/// グループ一覧にメンバーの概要を表示します。
private struct GroupMemberRow: View {
    let profile: GroupMemberProfile

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(user: profile.user, size: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(profile.user.displayName)
                        .font(.headline)
                    Spacer()
                    Text(profile.member.role.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(profile.visibleBirthdayText)

                if let daysUntilText = profile.daysUntilText {
                    Text(daysUntilText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("プロフィールを開きます")
    }

    /// VoiceOver向けに公開中の情報だけを読み上げます。
    private var accessibilityLabel: String {
        let values = [
            profile.user.displayName,
            profile.member.role.label,
            profile.visibleBirthdayText,
            profile.daysUntilText
        ]
        return values.compactMap { $0 }.joined(separator: "、")
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(
            group: BirthdayGroup(
                groupId: "preview-group",
                name: "サンプルグループ",
                ownerId: "preview-user",
                inviteCode: "ABC123"
            )
        )
    }
    .environment(AuthViewModel())
}
