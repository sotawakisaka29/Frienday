//
//  AppError.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

/// 画面に表示しやすい日本語メッセージを持つアプリ共通エラーです。
enum AppError: LocalizedError, Equatable {
    case invalidDisplayName
    case displayNameTooLong
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case emailAlreadyInUse
    case wrongEmailOrPassword
    case authProviderDisabled
    case invalidFirebaseConfiguration
    case missingGoogleClientID
    case googleSignInCanceled
    case googleSignInFailed
    case tooManyRequests
    case networkError
    case notSignedIn
    case invalidBirthday
    case futureBirthday
    case profileNotLoaded
    case invalidProfileImage
    case profileImageTooLarge
    case firebaseStorageNotConfigured
    case profileImageUploadFailed
    case profileImageDeleteFailed
    case invalidGroupName
    case groupNameTooLong
    case groupNotFound
    case invalidInviteCode
    case inviteCodeGenerationFailed
    case alreadyJoinedGroup
    case permissionDenied
    case firestoreSaveFailed
    case notificationPermissionDenied
    case requiresRecentLogin
    case ownerCannotLeaveWithMembers
    case unknown

    var errorDescription: String? {
        message
    }

    var message: String {
        switch self {
        case .invalidDisplayName: return "表示名を入力してください。"
        case .displayNameTooLong: return "表示名は30文字以内で入力してください。"
        case .invalidEmail: return "メールアドレスの形式が正しくありません。"
        case .weakPassword: return "パスワードは6文字以上で入力してください。"
        case .passwordMismatch: return "確認用パスワードが一致していません。"
        case .emailAlreadyInUse: return "このメールアドレスはすでに使われています。"
        case .wrongEmailOrPassword: return "メールアドレスまたはパスワードが正しくありません。"
        case .authProviderDisabled: return "Firebase Authentication の Email/Password 認証が有効になっていません。Firebase Consoleで有効化してください。"
        case .invalidFirebaseConfiguration: return "Firebaseの設定がアプリと一致していません。GoogleService-Info.plist、Bundle Identifier、FirebaseのiOSアプリ設定を確認してください。"
        case .missingGoogleClientID: return "Googleログイン設定が不足しています。Firebase ConsoleでGoogleログインを有効化し、新しいGoogleService-Info.plistを追加してください。"
        case .googleSignInCanceled: return "Googleログインがキャンセルされました。"
        case .googleSignInFailed: return "Googleログインに失敗しました。Firebase ConsoleのGoogleプロバイダ設定とURL Schemeを確認してください。"
        case .tooManyRequests: return "短時間に何度も試行されました。少し時間をおいてから再度お試しください。"
        case .networkError: return "通信環境を確認して、もう一度お試しください。"
        case .notSignedIn: return "ログインが必要です。"
        case .invalidBirthday: return "生年月日を正しく入力してください。"
        case .futureBirthday: return "未来の日付は生年月日に設定できません。"
        case .profileNotLoaded: return "プロフィールを読み込めませんでした。画面を開き直して、もう一度お試しください。"
        case .invalidProfileImage: return "画像ファイルを選択してください。"
        case .profileImageTooLarge: return "プロフィール画像は5MB以下のものを選択してください。"
        case .firebaseStorageNotConfigured: return "Firebase Storageの設定が必要です。XcodeでFirebaseStorageをターゲットに追加してください。"
        case .profileImageUploadFailed: return "プロフィール画像の保存に失敗しました。Storageの設定とSecurity Rulesを確認してください。"
        case .profileImageDeleteFailed: return "プロフィール画像の削除に失敗しました。"
        case .invalidGroupName: return "グループ名を入力してください。"
        case .groupNameTooLong: return "グループ名は40文字以内で入力してください。"
        case .groupNotFound: return "グループが見つかりません。"
        case .invalidInviteCode: return "招待コードが正しくありません。"
        case .inviteCodeGenerationFailed: return "招待コードを作成できませんでした。もう一度お試しください。"
        case .alreadyJoinedGroup: return "すでにこのグループに参加しています。"
        case .permissionDenied: return "Firestoreの権限がありません。Firebase ConsoleでSecurity Rulesを確認してください。"
        case .firestoreSaveFailed: return "Firestoreへの保存に失敗しました。Firestore Databaseが作成済みか確認してください。"
        case .notificationPermissionDenied: return "通知が許可されていません。設定アプリから通知を許可してください。"
        case .requiresRecentLogin: return "安全のため、もう一度ログインしてから操作してください。"
        case .ownerCannotLeaveWithMembers: return "ownerは他のメンバーがいる間は退会できません。先にグループを削除してください。"
        case .unknown: return "処理に失敗しました。時間をおいて再度お試しください。"
        }
    }

    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let nsError = error as NSError

        if nsError.domain == "com.google.GIDSignIn" {
            if nsError.code == -5 {
                return .googleSignInCanceled
            }
            return .googleSignInFailed
        }

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return .invalidEmail
            case .weakPassword:
                return .weakPassword
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .wrongPassword, .userNotFound, .invalidCredential:
                return .wrongEmailOrPassword
            case .operationNotAllowed:
                return .authProviderDisabled
            case .invalidAPIKey, .appNotAuthorized:
                return .invalidFirebaseConfiguration
            case .tooManyRequests:
                return .tooManyRequests
            case .networkError:
                return .networkError
            case .requiresRecentLogin:
                return .requiresRecentLogin
            default:
                return .unknown
            }
        }

        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .permissionDenied:
                return .permissionDenied
            case .notFound:
                return .groupNotFound
            case .unavailable:
                return .networkError
            default:
                return .firestoreSaveFailed
            }
        }

        return .unknown
    }
}
