//
//  GroupListView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// 所属グループの一覧と作成・参加ボタンを表示します。
struct GroupListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = GroupListViewModel()
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var activeSheet: GroupSheet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        GroupActionButton(title: "新規", systemImage: "plus") {
                            showSheet(.create)
                        }

                        GroupActionButton(title: "参加", systemImage: "person.badge.plus") {
                            showSheet(.join)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("所属グループ") {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.groups.isEmpty {
                        ContentUnavailableView("グループがありません", systemImage: "person.3", description: Text("最初のグループを作成しましょう。"))
                    } else {
                        ForEach(viewModel.groups) { group in
                            NavigationLink(value: group) {
                                GroupRow(group: group, summary: viewModel.summaries[group.groupId])
                            }
                        }
                    }
                }
            }
            .navigationTitle("グループ")
            .navigationDestination(for: BirthdayGroup.self) { group in
                GroupDetailView(group: group)
            }
            .refreshable {
                await load()
            }
            .task {
                await load()
            }
            .sheet(item: $activeSheet, onDismiss: resetInput) { sheet in
                switch sheet {
                case .create:
                    GroupInputSheet(
                        mode: .create,
                        text: $groupName,
                        isProcessing: viewModel.isProcessing,
                        errorMessage: viewModel.errorMessage
                    ) {
                        Task { await createGroup() }
                    }
                    .presentationDetents([.medium])
                case .join:
                    GroupInputSheet(
                        mode: .join,
                        text: $inviteCode,
                        isProcessing: viewModel.isProcessing,
                        errorMessage: viewModel.errorMessage
                    ) {
                        Task { await joinGroup() }
                    }
                    .presentationDetents([.medium])
                case .created(let group):
                    CreatedGroupInviteView(group: group)
                        .presentationDetents([.medium])
                }
            }
        }
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.load(userId: userId)
    }

    private func createGroup() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        if let group = await viewModel.createGroup(name: groupName, userId: userId) {
            groupName = ""
            activeSheet = .created(group)
        }
    }

    private func joinGroup() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        if await viewModel.joinGroup(inviteCode: inviteCode, userId: userId) {
            inviteCode = ""
            activeSheet = nil
        }
    }

    /// 前回のエラーを消去して、指定されたモーダルを開きます。
    private func showSheet(_ sheet: GroupSheet) {
        viewModel.clearError()
        activeSheet = sheet
    }

    /// モーダルを閉じたときに入力内容とエラーを初期化します。
    private func resetInput() {
        groupName = ""
        inviteCode = ""
        viewModel.clearError()
    }
}

/// グループ画面から開くモーダルの種類です。
private enum GroupSheet: Identifiable {
    case create
    case join
    case created(BirthdayGroup)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .join:
            return "join"
        case .created(let group):
            return "created-\(group.groupId)"
        }
    }
}

/// グループの新規作成と参加を選ぶ大きな正方形ボタンです。
private struct GroupActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.tint)
            .background(Color.secondary.opacity(0.1))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// 新規作成と招待コード参加で共通利用する入力モーダルです。
private struct GroupInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let mode: GroupInputMode
    @Binding var text: String
    let isProcessing: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(mode.fieldTitle) {
                    TextField(mode.placeholder, text: inputBinding)
                        .textInputAutocapitalization(mode == .join ? .characters : .sentences)
                        .autocorrectionDisabled(mode == .join)
                        .submitLabel(mode == .join ? .join : .done)
                        .focused($isFocused)
                        .onSubmit(submit)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isProcessing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.actionTitle, action: submit)
                        .disabled(trimmedText.isEmpty || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView()
                }
            }
            .task {
                isFocused = true
            }
        }
    }

    /// 空白だけの入力を除外するための文字列を返します。
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 招待コードは半角英大文字と数字の6文字までに整えます。
    private var inputBinding: Binding<String> {
        Binding {
            text
        } set: { newValue in
            guard mode == .join else {
                text = newValue
                return
            }

            let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            let normalizedCode = newValue
                .uppercased()
                .filter { allowedCharacters.contains($0) }
            text = String(normalizedCode.prefix(6))
        }
    }

    /// 入力済みで処理中でない場合だけ送信します。
    private func submit() {
        guard !trimmedText.isEmpty, !isProcessing else { return }
        onSubmit()
    }
}

/// 入力モーダルの表示文言と入力設定を切り替えます。
private enum GroupInputMode: Equatable {
    case create
    case join

    var title: String {
        self == .create ? "新しいグループ" : "グループに参加"
    }

    var fieldTitle: String {
        self == .create ? "グループ名" : "招待コード"
    }

    var placeholder: String {
        self == .create ? "グループ名" : "A1B2C3"
    }

    var actionTitle: String {
        self == .create ? "作成" : "参加"
    }
}

/// 作成されたグループの招待コードを表示します。
private struct CreatedGroupInviteView: View {
    @Environment(\.dismiss) private var dismiss

    let group: BirthdayGroup

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text(group.name)
                        .font(.headline)
                    Text("招待コード")
                        .foregroundStyle(.secondary)
                    Text(group.inviteCode)
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .textSelection(.enabled)
                        .accessibilityLabel("招待コード \(group.inviteCode)")
                }

                ShareLink(item: "Friendayの「\(group.name)」に参加してください。招待コード: \(group.inviteCode)") {
                    Label("招待コードを共有", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("グループを作成しました")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// グループ一覧の1行表示です。
struct GroupRow: View {
    let group: BirthdayGroup
    let summary: GroupSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.name)
                .font(.headline)
            Text("メンバー \(summary?.memberCount ?? 0)人")
                .foregroundStyle(.secondary)

            if let item = summary?.nextBirthdayItem {
                Text("次は\(item.user.displayName)さん ・ あと\(item.daysUntilBirthday)日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("表示できる誕生日はまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(group.name)、メンバー\(summary?.memberCount ?? 0)人")
    }
}

#Preview {
    GroupListView()
        .environment(AuthViewModel())
}

#Preview("作成完了") {
    CreatedGroupInviteView(
        group: BirthdayGroup(
            groupId: "preview-group",
            name: "友だち",
            ownerId: "preview-user",
            inviteCode: "A7K9Q2"
        )
    )
}
