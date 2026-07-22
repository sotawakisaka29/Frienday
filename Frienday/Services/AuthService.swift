//
//  AuthService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

/// Firebase Authentication を使った認証処理を担当します。
protocol AuthServiceProtocol {
    var currentUser: User? { get }

    @discardableResult
    func signUp(email: String, password: String) async throws -> User

    @discardableResult
    func signIn(email: String, password: String) async throws -> User

    @discardableResult
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> User

    func signOut() throws
    func sendPasswordReset(email: String) async throws
    func deleteAccount() async throws
    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle)
}

/// Firebase Authentication を使った認証処理を担当します。
struct AuthService: AuthServiceProtocol {
    private let auth: Auth

    init(auth: Auth = FirebaseManager.shared.auth) {
        self.auth = auth
    }

    var currentUser: User? {
        auth.currentUser
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> User {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return result.user
        } catch {
            throw AppError.map(error)
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> User {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return result.user
        } catch {
            throw AppError.map(error)
        }
    }

    @discardableResult
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AppError.missingGoogleClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppError.googleSignInFailed
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await auth.signIn(with: credential)
            return authResult.user
        } catch {
            throw AppError.map(error)
        }
    }

    func signOut() throws {
        do {
            GIDSignIn.sharedInstance.signOut()
            try auth.signOut()
        } catch {
            throw AppError.map(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            throw AppError.map(error)
        }
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AppError.notSignedIn
        }

        do {
            try await user.delete()
        } catch {
            throw AppError.map(error)
        }
    }

    func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        auth.addStateDidChangeListener { _, user in
            listener(user)
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }
}
