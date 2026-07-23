//
//  ValidationUtility.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import Foundation

/// 入力値を整えて、問題があれば AppError を返します。
enum ValidationUtility {
    static func validateDisplayName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidDisplayName }
        guard trimmed.count <= 30 else { throw AppError.displayNameTooLong }
        return trimmed
    }

    static func validateEmail(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { throw AppError.invalidEmail }

        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            throw AppError.invalidEmail
        }

        return trimmed
    }

    static func validatePassword(_ password: String, confirmation: String? = nil) throws -> String {
        guard password.count >= 6 else { throw AppError.weakPassword }
        if let confirmation, password != confirmation {
            throw AppError.passwordMismatch
        }
        return password
    }

    static func validateBirthday(_ date: Date, calendar: Calendar = .current) throws -> DateComponents {
        guard date <= Date() else { throw AppError.futureBirthday }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year != nil, components.month != nil, components.day != nil else {
            throw AppError.invalidBirthday
        }

        return components
    }

    static func validateGroupName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidGroupName }
        guard trimmed.count <= 40 else { throw AppError.groupNameTooLong }
        return trimmed
    }

    static func normalizeInviteCode(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw AppError.invalidInviteCode }
        return normalized
    }

    /// 個人チャットの本文を空白除去後1〜50文字に整えます。
    static func validateChatMessage(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.emptyChatMessage }
        guard trimmed.count <= 50 else { throw AppError.chatMessageTooLong }
        return trimmed
    }
}
