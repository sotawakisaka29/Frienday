//
//  AppUser.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// Frienday に登録されたユーザーのプロフィールです。
struct AppUser: Identifiable, Hashable {
    var id: String { userId }

    let userId: String
    var displayName: String
    var email: String
    var birthYear: Int
    var birthMonth: Int
    var birthDay: Int
    var createdAt: Date?
    var updatedAt: Date?

    var birthdayText: String {
        "\(birthYear)年\(birthMonth)月\(birthDay)日"
    }

    var publicBirthdayText: String {
        "\(birthMonth)月\(birthDay)日"
    }

    init(
        userId: String,
        displayName: String,
        email: String,
        birthYear: Int,
        birthMonth: Int,
        birthDay: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.birthYear = birthYear
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(id: String, data: [String: Any]) {
        guard let displayName = data["displayName"] as? String,
              let email = data["email"] as? String,
              let birthYear = data["birthYear"] as? Int,
              let birthMonth = data["birthMonth"] as? Int,
              let birthDay = data["birthDay"] as? Int else {
            return nil
        }

        userId = id
        self.displayName = displayName
        self.email = email
        self.birthYear = birthYear
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }

    func dataForCreate() -> [String: Any] {
        [
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func dataForPublicProfile() -> [String: Any] {
        [
            "userId": userId,
            "displayName": displayName,
            "birthYear": FieldValue.delete(),
            "birthMonth": birthMonth,
            "birthDay": birthDay,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func dataForPrivateProfile() -> [String: Any] {
        [
            "userId": userId,
            "email": email,
            "birthYear": birthYear,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func dataForPublicUpdate() -> [String: Any] {
        [
            "displayName": displayName,
            "birthYear": FieldValue.delete(),
            "birthMonth": birthMonth,
            "birthDay": birthDay,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func dataForPrivateUpdate() -> [String: Any] {
        [
            "email": email,
            "birthYear": birthYear,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
