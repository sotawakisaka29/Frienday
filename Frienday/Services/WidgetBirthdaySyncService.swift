//
//  WidgetBirthdaySyncService.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import CryptoKit
import Foundation
import UIKit
import WidgetKit

/// 公開が許可された誕生日情報をウィジェットへ共有します。
struct WidgetBirthdaySyncService {
    private let groupRepository: GroupRepository
    private let userRepository: UserRepository
    private let defaults: UserDefaults?

    init(
        groupRepository: GroupRepository = GroupRepository(),
        userRepository: UserRepository = UserRepository(),
        defaults: UserDefaults? = UserDefaults(suiteName: WidgetBirthdayConfiguration.appGroupIdentifier)
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.defaults = defaults
    }

    /// 読み込み済みの画面表示データをウィジェット用に保存します。
    func save(items: [BirthdayDisplayItem]) {
        var seenUserIds = Set<String>()
        let candidates = items.compactMap { item -> WidgetBirthdayCandidate? in
            guard item.member.showBirthday,
                  seenUserIds.insert(item.user.userId).inserted else {
                return nil
            }

            return WidgetBirthdayCandidate(user: item.user)
        }

        save(candidates: candidates)
    }

    /// Firebaseから現在の公開対象を読み直してウィジェットへ保存します。
    func refresh(userId: String) async throws {
        let groups = try await groupRepository.fetchUserGroups(userId: userId)
        var seenUserIds = Set<String>()
        var candidates: [WidgetBirthdayCandidate] = []

        for group in groups {
            let members = try await groupRepository.fetchMembers(groupId: group.groupId)

            for member in members where member.showBirthday && !seenUserIds.contains(member.userId) {
                guard let user = try? await userRepository.fetchPublicProfile(userId: member.userId) else {
                    continue
                }

                seenUserIds.insert(member.userId)
                candidates.append(WidgetBirthdayCandidate(user: user))
            }
        }

        save(candidates: candidates)
    }

    /// ログアウトした利用者の誕生日情報を共有領域から消去します。
    func clear() {
        defaults?.removeObject(forKey: WidgetBirthdayConfiguration.storageKey)
        if let imageDirectoryURL {
            try? FileManager.default.removeItem(at: imageDirectoryURL)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBirthdayConfiguration.kind)
    }

    /// すでに共有済みの画像を反映し、新しい画像の保存を開始します。
    private func save(candidates: [WidgetBirthdayCandidate]) {
        let people = candidates.map { candidate in
            candidate.person(imageFileName: existingImageFileName(for: candidate))
        }
        save(people: people)

        guard candidates.contains(where: { $0.profileImageURL != nil }) else {
            return
        }

        Task { @MainActor in
            await cacheProfileImages(for: candidates)
        }
    }

    /// プロフィール画像を縮小して共有フォルダへ保存します。
    private func cacheProfileImages(for candidates: [WidgetBirthdayCandidate]) async {
        var people: [WidgetBirthdayPerson] = []

        for candidate in candidates {
            guard let imageURL = candidate.profileImageURL,
                  let imageFileName = imageFileName(for: candidate) else {
                people.append(candidate.person(imageFileName: nil))
                continue
            }

            if imageFileExists(named: imageFileName) {
                people.append(candidate.person(imageFileName: imageFileName))
                continue
            }

            let storedFileName = await downloadAndStoreImage(
                from: imageURL,
                fileName: imageFileName
            )
            people.append(candidate.person(imageFileName: storedFileName))
        }

        save(people: people)
    }

    /// エンコードした誕生日情報をApp Groupへ保存します。
    private func save(people: [WidgetBirthdayPerson]) {
        let sortedPeople = people.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }

        guard let data = try? JSONEncoder().encode(sortedPeople) else {
            return
        }

        defaults?.set(data, forKey: WidgetBirthdayConfiguration.storageKey)
        removeUnusedImages(keeping: Set(sortedPeople.compactMap(\.imageFileName)))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetBirthdayConfiguration.kind)
    }

    /// URLから画像を取得し、ウィジェット向けの小さい画像として保存します。
    private func downloadAndStoreImage(from url: URL, fileName: String) async -> String? {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              data.count <= 8 * 1024 * 1024,
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data),
              let thumbnailData = thumbnailData(for: image),
              let imageDirectoryURL else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: imageDirectoryURL,
                withIntermediateDirectories: true
            )
            try thumbnailData.write(
                to: imageDirectoryURL.appendingPathComponent(fileName),
                options: .atomic
            )
            return fileName
        } catch {
            return nil
        }
    }

    /// プロフィール画像を192ピクセルの正方形へ縮小します。
    private func thumbnailData(for image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let targetSize = CGSize(width: 192, height: 192)
        let scale = max(
            targetSize.width / image.size.width,
            targetSize.height / image.size.height
        )
        let drawingSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let drawingOrigin = CGPoint(
            x: (targetSize.width - drawingSize.width) / 2,
            y: (targetSize.height - drawingSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: drawingOrigin, size: drawingSize))
        }
        return thumbnail.pngData()
    }

    /// プロフィールURLと更新日時から、安全な画像ファイル名を作ります。
    private func imageFileName(for candidate: WidgetBirthdayCandidate) -> String? {
        guard let profileImageURL = candidate.profileImageURL else {
            return nil
        }

        let version = candidate.profileUpdatedAt?.timeIntervalSince1970.description ?? ""
        let source = "\(candidate.userId)|\(profileImageURL.absoluteString)|\(version)"
        let digest = SHA256.hash(data: Data(source.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "profile-\(hash).png"
    }

    /// 共有フォルダに存在する画像だけを表示データへ関連付けます。
    private func existingImageFileName(for candidate: WidgetBirthdayCandidate) -> String? {
        guard let fileName = imageFileName(for: candidate),
              imageFileExists(named: fileName) else {
            return nil
        }
        return fileName
    }

    /// 指定された共有画像が保存済みか確認します。
    private func imageFileExists(named fileName: String) -> Bool {
        guard let imageDirectoryURL else {
            return false
        }
        return FileManager.default.fileExists(
            atPath: imageDirectoryURL.appendingPathComponent(fileName).path
        )
    }

    /// 現在の表示データから使われなくなった共有画像を消去します。
    private func removeUnusedImages(keeping fileNames: Set<String>) {
        guard let imageDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: imageDirectoryURL,
                includingPropertiesForKeys: nil
              ) else {
            return
        }

        for fileURL in files where !fileNames.contains(fileURL.lastPathComponent) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// App Group内にあるプロフィール画像用フォルダの場所です。
    private var imageDirectoryURL: URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: WidgetBirthdayConfiguration.appGroupIdentifier
            )?
            .appendingPathComponent(
                WidgetBirthdayConfiguration.imageDirectoryName,
                isDirectory: true
            )
    }
}

/// アプリ本体が保存するウィジェット用の最小プロフィールです。
private struct WidgetBirthdayPerson: Codable {
    let id: String
    let displayName: String
    let birthMonth: Int
    let birthDay: Int
    let imageColorHex: String
    let imageFileName: String?

    init(candidate: WidgetBirthdayCandidate, imageFileName: String?) {
        id = candidate.userId
        displayName = candidate.displayName
        birthMonth = candidate.birthMonth
        birthDay = candidate.birthDay
        imageColorHex = candidate.imageColorHex
        self.imageFileName = imageFileName
    }
}

/// ウィジェットへ渡すプロフィールと画像取得情報をまとめます。
private struct WidgetBirthdayCandidate {
    let userId: String
    let displayName: String
    let birthMonth: Int
    let birthDay: Int
    let imageColorHex: String
    let profileImageURL: URL?
    let profileUpdatedAt: Date?

    init(user: AppUser) {
        userId = user.userId
        displayName = user.displayName
        birthMonth = user.birthMonth
        birthDay = user.birthDay
        imageColorHex = user.imageColorHex
        profileImageURL = user.profileImageURL.flatMap(URL.init(string:))
        profileUpdatedAt = user.updatedAt
    }

    /// 共有画像名を含む、保存用プロフィールを作ります。
    func person(imageFileName: String?) -> WidgetBirthdayPerson {
        WidgetBirthdayPerson(candidate: self, imageFileName: imageFileName)
    }
}

/// アプリ本体とウィジェットで一致させる共有設定です。
private enum WidgetBirthdayConfiguration {
    static let appGroupIdentifier = "group.app.Wakisaka.Wakiso.Frienday"
    static let storageKey = "widgetBirthdayPeople"
    static let imageDirectoryName = "WidgetProfileImages"
    static let kind = "FriendayWidget"
}
