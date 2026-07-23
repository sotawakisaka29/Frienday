//
//  SettingsView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth
import PhotosUI
import UIKit

/// プロフィール編集、通知、ログアウト、アカウント削除を行う設定画面です。
struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Bindable var viewModel: SettingsViewModel
    @State private var resetEmail = ""
    @State private var showsDeleteConfirmation = false
    @State private var birthdayItems: [BirthdayDisplayItem] = []
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var profileImageCropItem: ProfileImageCropItem?
    @State private var isEditingProfile = false

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                notificationSection
                accountSection

                if let successMessage = viewModel.successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage = viewModel.errorMessage ?? authViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("設定")
            .task {
                await load()
            }
            .onDisappear {
                if !viewModel.hasProfileChanges {
                    isEditingProfile = false
                }
            }
            .onChange(of: selectedProfileImage) { _, item in
                guard let item else { return }
                Task { await loadProfileImage(from: item) }
            }
            .sheet(item: $profileImageCropItem) { item in
                ProfileImageCropView(
                    image: item.image,
                    onCancel: {
                        profileImageCropItem = nil
                    },
                    onComplete: { croppedData in
                        viewModel.setProfileImage(data: croppedData, contentType: "image/jpeg")
                        profileImageCropItem = nil
                    }
                )
            }
            .confirmationDialog("アカウントを削除しますか？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var profileSection: some View {
        Section {
            VStack(spacing: 14) {
                ProfileAvatarView(
                    displayName: viewModel.profileDisplayName,
                    imageURL: viewModel.profileImageURL,
                    imageData: viewModel.pendingProfileImageData,
                    colorHex: viewModel.profileImageColorHex,
                    size: 104
                )

                if isEditingProfile {
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selectedProfileImage, matching: .images) {
                            Label("画像を選択", systemImage: "photo")
                        }

                        if viewModel.hasProfileImage {
                            Button("削除", role: .destructive) {
                                selectedProfileImage = nil
                                viewModel.removeProfileImage()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if isEditingProfile {
                TextField("表示名", text: profileDisplayNameBinding)

                VStack(alignment: .leading, spacing: 6) {
                    Text("自己紹介")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        if viewModel.profileBio.isEmpty {
                            Text("自己紹介を入力")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }

                        TextEditor(text: profileBioBinding)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                    }

                    Text("\(viewModel.profileBio.count)/100")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                BirthdayPicker(selection: profileBirthdayBinding)

                VStack(alignment: .leading, spacing: 12) {
                    Text("イメージカラー")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProfileColorPicker(selection: profileImageColorBinding)
                }
                .padding(.vertical, 4)

                HStack {
                    Button("キャンセル", role: .cancel) {
                        cancelProfileEditing()
                    }
                    .disabled(viewModel.isSavingProfile)

                    Spacer()

                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if viewModel.isSavingProfile {
                            ProgressView()
                        } else {
                            Label("保存", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(viewModel.isSavingProfile)
                }
            } else {
                LabeledContent("表示名", value: viewModel.profileDisplayName)

                VStack(alignment: .leading, spacing: 6) {
                    Text("自己紹介")
                        .foregroundStyle(.secondary)
                    Text(viewModel.profileBio.isEmpty ? "未設定" : viewModel.profileBio)
                        .foregroundStyle(viewModel.profileBio.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LabeledContent("誕生日") {
                    Text(DateUtility.fullDateFormatter.string(from: viewModel.profileBirthday))
                }

                LabeledContent("イメージカラー") {
                    Circle()
                        .fill(Color(profileHex: viewModel.profileImageColorHex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        }
                        .accessibilityLabel("選択中のイメージカラー")
                }
            }
        } header: {
            HStack {
                Text("プロフィール")
                Spacer()
                if !isEditingProfile {
                    Button("編集") {
                        viewModel.clearFeedback()
                        isEditingProfile = true
                    }
                    .disabled(viewModel.profile == nil || viewModel.isLoading)
                }
            }
        }
    }

    private var notificationSection: some View {
        Section("通知") {
            Toggle("通知オン", isOn: Binding(
                get: { viewModel.notificationSettings.isEnabled },
                set: { viewModel.setNotificationsEnabled($0) }
            ))
            Toggle("当日通知", isOn: Binding(
                get: { viewModel.notificationSettings.notifyOnDay },
                set: { viewModel.setNotifyOnDay($0) }
            ))
            Toggle("前日通知", isOn: Binding(
                get: { viewModel.notificationSettings.notifyDayBefore },
                set: { viewModel.setNotifyDayBefore($0) }
            ))
            DatePicker("通知時刻", selection: notificationTimeBinding, displayedComponents: .hourAndMinute)

            if viewModel.hasNotificationChanges {
                Button {
                    Task { await viewModel.updateNotifications(items: birthdayItems) }
                } label: {
                    if viewModel.isUpdatingNotifications {
                        ProgressView()
                    } else {
                        Label("通知を更新", systemImage: "bell.badge")
                    }
                }
                .disabled(viewModel.isUpdatingNotifications)
            }
        }
    }

    private var accountSection: some View {
        Section("アカウント") {
            TextField("メールアドレス", text: $resetEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await authViewModel.sendPasswordReset(email: resetEmail) }
            } label: {
                Label("パスワード再設定メールを送る", systemImage: "envelope")
            }

            Button(role: .destructive) {
                Task {
                    do {
                        viewModel.clearNotifications()
                        try await authViewModel.signOut()
                    } catch {
                        return
                    }
                }
            } label: {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("アカウント削除", systemImage: "trash")
            }
        }
    }

    private var notificationTimeBinding: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = viewModel.notificationSettings.notificationHour
            components.minute = viewModel.notificationSettings.notificationMinute
            return Calendar.current.date(from: components) ?? Date()
        } set: { date in
            viewModel.setNotificationTime(date)
        }
    }

    private var profileDisplayNameBinding: Binding<String> {
        Binding {
            viewModel.profileDisplayName
        } set: { value in
            viewModel.setProfileDisplayName(value)
        }
    }

    private var profileBioBinding: Binding<String> {
        Binding {
            viewModel.profileBio
        } set: { value in
            viewModel.setProfileBio(value)
        }
    }

    private var profileBirthdayBinding: Binding<Date> {
        Binding {
            viewModel.profileBirthday
        } set: { value in
            viewModel.setProfileBirthday(value)
        }
    }

    private var profileImageColorBinding: Binding<String> {
        Binding {
            viewModel.profileImageColorHex
        } set: { value in
            viewModel.setProfileImageColor(value)
        }
    }

    /// PhotosPickerから選択した画像を読み込み、切り取り画面を表示します。
    private func loadProfileImage(from item: PhotosPickerItem) async {
        defer { selectedProfileImage = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.showProfileImageLoadError()
                return
            }

            profileImageCropItem = ProfileImageCropItem(image: image)
        } catch {
            viewModel.showProfileImageLoadError()
        }
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.loadProfile(userId: userId)
        if let profile = viewModel.profile {
            resetEmail = profile.email
        }

        let homeViewModel = HomeViewModel()
        birthdayItems = (try? await homeViewModel.loadBirthdayItems(userId: userId)) ?? []
    }

    private func cancelProfileEditing() {
        selectedProfileImage = nil
        profileImageCropItem = nil
        viewModel.discardProfileChanges()
        isEditingProfile = false
    }

    private func saveProfile() async {
        guard viewModel.hasProfileChanges else {
            isEditingProfile = false
            return
        }

        await viewModel.updateProfile()
        if !viewModel.hasProfileChanges && viewModel.errorMessage == nil {
            isEditingProfile = false
        }
    }

    private func deleteAccount() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.deleteAccount(userId: userId, authViewModel: authViewModel)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
        .environment(AuthViewModel())
}
