//
//  ProfileAvatarView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI
import UIKit

/// プロフィール画像、または表示名の頭文字を丸いアバターで表示します。
struct ProfileAvatarView: View {
    let displayName: String
    let imageURL: String?
    let imageData: Data?
    let colorHex: String
    let size: CGFloat

    @State private var loadedImage: UIImage?
    @State private var loadedImageURL: URL?
    @State private var failedImageURL: URL?

    init(user: AppUser, size: CGFloat) {
        displayName = user.displayName
        imageURL = user.profileImageURL
        imageData = nil
        colorHex = user.imageColorHex
        self.size = size
    }

    init(displayName: String, imageURL: String?, imageData: Data?, colorHex: String, size: CGFloat) {
        self.displayName = displayName
        self.imageURL = imageURL
        self.imageData = imageData
        self.colorHex = colorHex
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(profileColor.opacity(0.18))

            avatarContent
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(profileColor, lineWidth: max(2, size * 0.04))
        }
        .accessibilityLabel("\(displayName)のプロフィール画像")
    }

    /// 編集中の画像、保存済み画像、頭文字の順に表示します。
    @ViewBuilder
    private var avatarContent: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let imageURL, let url = URL(string: imageURL) {
            Group {
                if loadedImageURL == url, let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                } else if failedImageURL == url {
                    initialsView
                } else {
                    ProgressView()
                }
            }
            .task(id: url) {
                await loadProfileImage(from: url)
            }
        } else {
            initialsView
        }
    }

    private func loadProfileImage(from url: URL) async {
        do {
            let image = try await ProfileImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            loadedImage = image
            loadedImageURL = url
            failedImageURL = nil
        } catch {
            guard !Task.isCancelled else { return }
            loadedImage = nil
            loadedImageURL = nil
            failedImageURL = url
        }
    }

    /// 画像がないときに表示名の頭文字を表示します。
    private var initialsView: some View {
        Text(String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(profileColor)
    }

    private var profileColor: Color {
        Color(profileHex: colorHex)
    }
}

/// プロフィールのイメージカラーをスウォッチから選択します。
struct ProfileColorPicker: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ProfileColor.allCases) { profileColor in
                Button {
                    selection = profileColor.rawValue
                } label: {
                    Circle()
                        .fill(Color(profileHex: profileColor.rawValue))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == profileColor.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(.primary.opacity(selection == profileColor.rawValue ? 0.7 : 0), lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("イメージカラー")
                .accessibilityAddTraits(selection == profileColor.rawValue ? .isSelected : [])
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProfileAvatarView(
            displayName: "Frienday",
            imageURL: nil,
            imageData: nil,
            colorHex: ProfileColor.teal.rawValue,
            size: 88
        )
        ProfileColorPicker(selection: .constant(ProfileColor.teal.rawValue))
    }
    .padding()
}
