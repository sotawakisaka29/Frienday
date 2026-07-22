//
//  GroupService.swift
//  Frienday
//
//  Created by Codex on 22/07/2026.
//

import FirebaseFirestore
import Foundation

/// グループ作成、参加、退会、削除を担当します。
struct GroupService {
    private static let inviteCodeLength = 6
    private static let maxInviteCodeAttempts = 20
    private static let inviteCodeCollisionDomain = "Frienday.InviteCodeCollision"

    private let database: Firestore

    init(database: Firestore = FirebaseManager.shared.firestore) {
        self.database = database
    }

    func createGroup(name: String, ownerId: String) async throws -> BirthdayGroup {
        let groupName = try ValidationUtility.validateGroupName(name)
        let groupRef = database.collection("groups").document()

        for _ in 0..<Self.maxInviteCodeAttempts {
            let inviteCode = makeInviteCode()
            let inviteRef = database.collection("inviteCodes").document(inviteCode)
            let group = BirthdayGroup(
                groupId: groupRef.documentID,
                name: groupName,
                ownerId: ownerId,
                inviteCode: inviteCode
            )
            let ownerMember = GroupMember(userId: ownerId, role: .owner)
            let userGroup = UserGroupSummary(groupId: group.groupId, name: group.name, role: .owner)

            do {
                _ = try await database.runTransaction { transaction, errorPointer -> Any? in
                    do {
                        let inviteSnapshot = try transaction.getDocument(inviteRef)
                        guard !inviteSnapshot.exists else {
                            errorPointer?.pointee = NSError(
                                domain: Self.inviteCodeCollisionDomain,
                                code: 1
                            )
                            return nil
                        }

                        transaction.setData(group.dataForCreate(), forDocument: groupRef)
                        transaction.setData(
                            ownerMember.dataForCreate(),
                            forDocument: groupRef.collection("members").document(ownerId)
                        )
                        transaction.setData(
                            userGroup.dataForCreate(),
                            forDocument: self.database.collection("users").document(ownerId).collection("groups").document(group.groupId)
                        )
                        transaction.setData(
                            [
                                "groupId": group.groupId,
                                "name": group.name,
                                "createdAt": FieldValue.serverTimestamp()
                            ],
                            forDocument: inviteRef
                        )
                        return nil
                    } catch let error as NSError {
                        errorPointer?.pointee = error
                        return nil
                    }
                }
                return group
            } catch {
                let nsError = error as NSError
                if nsError.domain == Self.inviteCodeCollisionDomain {
                    continue
                }
                throw AppError.map(error)
            }
        }

        throw AppError.inviteCodeGenerationFailed
    }

    func joinGroup(inviteCode rawInviteCode: String, userId: String) async throws {
        let inviteCode = try ValidationUtility.normalizeInviteCode(rawInviteCode)

        do {
            let inviteSnapshot = try await database.collection("inviteCodes").document(inviteCode).getDocument()
            guard let inviteData = inviteSnapshot.data(),
                  let groupId = inviteData["groupId"] as? String else {
                throw AppError.invalidInviteCode
            }

            guard let groupName = inviteData["name"] as? String else {
                throw AppError.invalidInviteCode
            }

            let memberRef = database.collection("groups").document(groupId).collection("members").document(userId)
            let existingMember = try await memberRef.getDocument()
            guard !existingMember.exists else {
                throw AppError.alreadyJoinedGroup
            }

            let batch = database.batch()
            let member = GroupMember(userId: userId, role: .member)
            let userGroup = UserGroupSummary(groupId: groupId, name: groupName, role: .member)
            batch.setData(member.dataForCreate(), forDocument: memberRef)
            batch.setData(userGroup.dataForCreate(), forDocument: database.collection("users").document(userId).collection("groups").document(groupId))
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchUserGroups(userId: String) async throws -> [BirthdayGroup] {
        do {
            let snapshot = try await database.collection("users").document(userId).collection("groups").getDocuments()
            var groups: [BirthdayGroup] = []

            for document in snapshot.documents {
                let groupSnapshot = try await database.collection("groups").document(document.documentID).getDocument()
                if let data = groupSnapshot.data(), let group = BirthdayGroup(id: groupSnapshot.documentID, data: data) {
                    groups.append(group)
                }
            }

            return groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchMembers(groupId: String) async throws -> [GroupMember] {
        do {
            let snapshot = try await database.collection("groups").document(groupId).collection("members").getDocuments()
            return snapshot.documents.compactMap { GroupMember(id: $0.documentID, data: $0.data()) }
        } catch {
            throw AppError.map(error)
        }
    }

    func updateMemberSettings(
        groupId: String,
        userId: String,
        showBirthday: Bool,
        showBirthYear: Bool,
        sharedBirthYear: Int?
    ) async throws {
        var data: [String: Any] = [
            "showBirthday": showBirthday,
            "showBirthYear": showBirthYear
        ]
        if showBirthYear, let sharedBirthYear {
            data["birthYear"] = sharedBirthYear
        } else {
            data["birthYear"] = FieldValue.delete()
        }

        do {
            try await database.collection("groups").document(groupId).collection("members").document(userId).setData(data, merge: true)
        } catch {
            throw AppError.map(error)
        }
    }

    func leaveGroup(group: BirthdayGroup, userId: String) async throws {
        let members = try await fetchMembers(groupId: group.groupId)
        guard let currentMember = members.first(where: { $0.userId == userId }) else {
            throw AppError.groupNotFound
        }

        if currentMember.role == .owner {
            guard members.count <= 1 else {
                throw AppError.ownerCannotLeaveWithMembers
            }
            try await deleteGroup(group: group, requesterId: userId)
            return
        }

        let batch = database.batch()
        batch.deleteDocument(database.collection("groups").document(group.groupId).collection("members").document(userId))
        batch.deleteDocument(database.collection("users").document(userId).collection("groups").document(group.groupId))

        do {
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }

    func deleteGroup(group: BirthdayGroup, requesterId: String) async throws {
        guard group.ownerId == requesterId else {
            throw AppError.permissionDenied
        }

        let members = try await fetchMembers(groupId: group.groupId)
        let batch = database.batch()
        let groupRef = database.collection("groups").document(group.groupId)

        for member in members {
            batch.deleteDocument(groupRef.collection("members").document(member.userId))
            batch.deleteDocument(database.collection("users").document(member.userId).collection("groups").document(group.groupId))
        }

        batch.deleteDocument(database.collection("inviteCodes").document(group.inviteCode))
        batch.deleteDocument(groupRef)

        do {
            try await batch.commit()
        } catch {
            throw AppError.map(error)
        }
    }

    private func makeInviteCode() -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var generator = SystemRandomNumberGenerator()
        var code = ""

        for _ in 0..<Self.inviteCodeLength {
            let index = Int.random(in: characters.indices, using: &generator)
            code.append(characters[index])
        }

        return code
    }
}
