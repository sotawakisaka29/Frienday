//
//  AuthViewModel.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseAuth
import Observation
import UIKit

/// ログイン状態と認証画面の操作を管理します。
@Observable
@MainActor
final class AuthViewModel {
    private let authService: AuthServiceProtocol
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private(set) var currentUser: User?
    private(set) var errorMessage: String?
    private(set) var isCheckingSession = true

    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
        currentUser = authService.currentUser
        startAuthStateListener()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    func signUp(email: String, password: String) async throws -> User {
        do {
            let user = try await authService.signUp(email: email, password: password)
            currentUser = user
            errorMessage = nil
            return user
        } catch {
            let appError = AppError.map(error)
            errorMessage = appError.message
            throw appError
        }
    }

    func signIn(email: String, password: String) async {
        do {
            currentUser = try await authService.signIn(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    func signInWithGoogle() async throws -> User {
        guard let presentingViewController = PresentationUtility.rootViewController() else {
            throw AppError.googleSignInFailed
        }

        do {
            let user = try await authService.signInWithGoogle(presentingViewController: presentingViewController)
            currentUser = user
            errorMessage = nil
            return user
        } catch {
            let appError = AppError.map(error)
            errorMessage = appError.message
            throw appError
        }
    }

    func signOut() throws {
        do {
            try authService.signOut()
            currentUser = nil
            errorMessage = nil
            stopAuthStateListener()
        } catch {
            let appError = AppError.map(error)
            errorMessage = appError.message
            throw appError
        }
    }

    func sendPasswordReset(email: String) async {
        do {
            let normalizedEmail = try ValidationUtility.validateEmail(email)
            try await authService.sendPasswordReset(email: normalizedEmail)
            errorMessage = nil
        } catch {
            errorMessage = AppError.map(error).message
        }
    }

    func deleteAuthAccount() async throws {
        do {
            try await authService.deleteAccount()
            currentUser = nil
            errorMessage = nil
            stopAuthStateListener()
        } catch {
            let appError = AppError.map(error)
            errorMessage = appError.message
            throw appError
        }
    }

    private func startAuthStateListener() {
        guard authStateHandle == nil else { return }

        authStateHandle = authService.addAuthStateListener { [weak self] user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isCheckingSession = false
            }
        }
    }

    private func stopAuthStateListener() {
        guard let authStateHandle else { return }
        authService.removeAuthStateListener(authStateHandle)
        self.authStateHandle = nil
    }
}
