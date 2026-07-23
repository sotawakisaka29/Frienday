//
//  GroupMemberProfileView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI

/// グループメンバーの公開プロフィールを表示します。
struct GroupMemberProfileView: View {
    let profile: GroupMemberProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                introductionSection
                birthdaySection
                membershipSection
            }
            .padding()
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// プロフィール画像、表示名、グループ内の役割を表示します。
    private var profileHeader: some View {
        VStack(spacing: 14) {
            ProfileAvatarView(user: profile.user, size: 128)

            Text(profile.user.displayName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(profile.member.role.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(profileHex: profile.user.imageColorHex))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(profileHex: profile.user.imageColorHex).opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    /// 公開されている自己紹介を表示します。
    private var introductionSection: some View {
        ProfileInformationCard(title: "自己紹介", systemImage: "text.alignleft") {
            Text(profile.user.bio.isEmpty ? "自己紹介はまだありません。" : profile.user.bio)
                .foregroundStyle(profile.user.bio.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// グループで設定された公開範囲に合わせて誕生日を表示します。
    private var birthdaySection: some View {
        ProfileInformationCard(title: "誕生日", systemImage: "gift.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.visibleBirthdayText)
                    .font(.headline)

                if let daysUntilText = profile.daysUntilText {
                    Text(daysUntilText)
                        .foregroundStyle(.secondary)
                } else {
                    Label("このメンバーは誕生日を非公開にしています", systemImage: "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 所属グループと参加日を表示します。
    private var membershipSection: some View {
        ProfileInformationCard(title: "グループ", systemImage: "person.3.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.group.name)
                    .font(.headline)

                if let joinedAt = profile.member.joinedAt {
                    Text("\(DateUtility.fullDateFormatter.string(from: joinedAt))に参加")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// プロフィール情報を共通デザインのカードで表示します。
private struct ProfileInformationCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        GroupMemberProfileView(
            profile: GroupMemberProfile(
                user: AppUser(
                    userId: "preview-user",
                    displayName: "山田 あおい",
                    email: "",
                    birthYear: 0,
                    birthMonth: 7,
                    birthDay: 23,
                    imageColorHex: ProfileColor.blue.rawValue,
                    bio: "音楽とカフェ巡りが好きです。"
                ),
                member: GroupMember(
                    userId: "preview-user",
                    role: .owner,
                    joinedAt: Date(),
                    showBirthday: true,
                    showBirthYear: false
                ),
                group: BirthdayGroup(
                    groupId: "preview-group",
                    name: "サンプルグループ",
                    ownerId: "preview-user",
                    inviteCode: "ABC123"
                ),
                nextBirthday: Date(),
                daysUntilBirthday: 0
            )
        )
    }
}
