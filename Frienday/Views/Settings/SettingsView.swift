//
//  SettingsView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// プロフィール編集、通知、ログアウト、アカウント削除を行う設定画面です。
struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = SettingsViewModel()
    @State private var resetEmail = ""
    @State private var showsDeleteConfirmation = false
    @State private var birthdayItems: [BirthdayDisplayItem] = []

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
            .confirmationDialog("アカウントを削除しますか？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var profileSection: some View {
        Section("プロフィール") {
            TextField("表示名", text: profileDisplayNameBinding)
            BirthdayPicker(selection: profileBirthdayBinding)

            if viewModel.hasProfileChanges {
                Button {
                    Task { await viewModel.updateProfile() }
                } label: {
                    if viewModel.isSavingProfile {
                        ProgressView()
                    } else {
                        Label("保存", systemImage: "checkmark.circle")
                    }
                }
                .disabled(viewModel.isSavingProfile)
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
                do {
                    viewModel.clearNotifications()
                    try authViewModel.signOut()
                } catch {
                    return
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

    private var profileBirthdayBinding: Binding<Date> {
        Binding {
            viewModel.profileBirthday
        } set: { value in
            viewModel.setProfileBirthday(value)
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

    private func deleteAccount() async {
        guard let userId = authViewModel.currentUser?.uid else { return }
        await viewModel.deleteAccount(userId: userId, authViewModel: authViewModel)
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
}
