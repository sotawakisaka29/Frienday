//
//  AuthView.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import SwiftUI
import FirebaseAuth

/// メールアドレスとパスワードで登録・ログインする画面です。
struct AuthView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var isSignUpMode = true
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var message: String?
    @State private var isWorking = false

    private let userRepository = UserRepository()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("モード", selection: $isSignUpMode) {
                        Text("新規登録").tag(true)
                        Text("ログイン").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("認証モード")
                }

                if isSignUpMode {
                    Section("プロフィール") {
                        TextField("表示名", text: $displayName)
                            .textContentType(.name)
                        BirthdayPicker(selection: $birthday)
                    }
                }

                Section("アカウント") {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)

                    SecureField("パスワード", text: $password)
                        .textContentType(isSignUpMode ? .newPassword : .password)

                    if isSignUpMode {
                        SecureField("パスワード確認", text: $passwordConfirmation)
                            .textContentType(.newPassword)
                    }
                }

                if let errorMessage = authViewModel.errorMessage ?? message {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel(errorMessage)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Label(isSignUpMode ? "アカウント作成" : "ログイン", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                    .disabled(isWorking)

                    Button("パスワード再設定メールを送る") {
                        Task { await authViewModel.sendPasswordReset(email: email) }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Button {
                        Task { await submitGoogle() }
                    } label: {
                        Label(isSignUpMode ? "Googleで登録" : "Googleでログイン", systemImage: "g.circle")
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Frienday")
        }
    }

    private func submit() async {
        isWorking = true
        message = nil

        do {
            let normalizedEmail = try ValidationUtility.validateEmail(email)
            let normalizedPassword = try ValidationUtility.validatePassword(password, confirmation: isSignUpMode ? passwordConfirmation : nil)

            if isSignUpMode {
                let normalizedName = try ValidationUtility.validateDisplayName(displayName)
                let birthdayComponents = try ValidationUtility.validateBirthday(birthday)
                guard let year = birthdayComponents.year,
                      let month = birthdayComponents.month,
                      let day = birthdayComponents.day else {
                    throw AppError.invalidBirthday
                }

                let firebaseUser = try await authViewModel.signUp(email: normalizedEmail, password: normalizedPassword)
                let appUser = AppUser(
                    userId: firebaseUser.uid,
                    displayName: normalizedName,
                    email: normalizedEmail,
                    birthYear: year,
                    birthMonth: month,
                    birthDay: day
                )
                try await userRepository.saveProfile(appUser)
            } else {
                await authViewModel.signIn(email: normalizedEmail, password: normalizedPassword)
            }
        } catch {
            let appError = AppError.map(error)
            if isSignUpMode, appError == .permissionDenied || appError == .firestoreSaveFailed {
                message = "アカウントは作成されましたが、プロフィール保存に失敗しました。Firestore Databaseが作成済みか、Security Rulesが設定済みか確認してください。"
            } else {
                message = appError.message
            }
        }

        isWorking = false
    }

    private func submitGoogle() async {
        isWorking = true
        message = nil

        do {
            let firebaseUser = try await authViewModel.signInWithGoogle()

            if isSignUpMode {
                let normalizedName = try ValidationUtility.validateDisplayName(
                    displayName.isEmpty ? firebaseUser.displayName ?? "" : displayName
                )
                let birthdayComponents = try ValidationUtility.validateBirthday(birthday)
                guard let year = birthdayComponents.year,
                      let month = birthdayComponents.month,
                      let day = birthdayComponents.day else {
                    throw AppError.invalidBirthday
                }

                let appUser = AppUser(
                    userId: firebaseUser.uid,
                    displayName: normalizedName,
                    email: firebaseUser.email ?? "",
                    birthYear: year,
                    birthMonth: month,
                    birthDay: day
                )
                try await userRepository.saveProfile(appUser)
            } else {
                do {
                    _ = try await userRepository.fetchProfile(userId: firebaseUser.uid)
                } catch {
                    try? await authViewModel.signOut()
                    message = "初回のGoogleログインでは、上の切り替えを「新規登録」にして表示名と生年月日を入力してください。"
                }
            }
        } catch {
            let appError = AppError.map(error)
            if isSignUpMode, appError == .permissionDenied || appError == .firestoreSaveFailed {
                message = "Googleアカウントは連携されましたが、プロフィール保存に失敗しました。Firestore Databaseが作成済みか、Security Rulesが設定済みか確認してください。"
            } else {
                message = appError.message
            }
        }

        isWorking = false
    }
}

#Preview {
    AuthView()
        .environment(AuthViewModel())
}
