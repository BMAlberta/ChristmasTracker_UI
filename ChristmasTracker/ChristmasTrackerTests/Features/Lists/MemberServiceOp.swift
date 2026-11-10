//
//  MemberServiceOp.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the four ListService member operations, for the parameterized service tests.
//  `script` queues the held step (and, for add and remove, the unheld refetch step), `run`
//  executes the operation, and `awaitHeld` / `releaseAll` drive the handshake on whichever
//  repository the operation talks to first.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum MemberServiceOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case addMember, removeMember, leaveList, setCoOwner

    var testDescription: String {
        switch self {
        case .addMember: "addMember"
        case .removeMember: "removeMember"
        case .leaveList: "leaveList"
        case .setCoOwner: "setCoOwner"
        }
    }

    /// Operations whose success is followed by a refetch of the detail.
    var refetches: Bool { self == .addMember || self == .removeMember }

    static let leaveUserId = "user-me"

    /// Queues the first repository step (held or not) with the given outcome. For add and remove
    /// a SUCCESS also queues an unheld refetch step returning `refetched`.
    @MainActor
    func script(_ sut: MemberServiceHarness, failing error: ListError?, held: Bool = true) throws {
        switch self {
        case .addMember:
            if let error {
                sut.members.enqueueAddMember(.failure(error), held: held)
            } else {
                sut.members.enqueueAddMember(.success(try MemberServiceHarness.addedMember()), held: held)
                sut.lists.enqueueFetchListDetail(.success(try MemberServiceHarness.detail(
                    roster: [MembersFixtures.ownerRow(), MembersFixtures.memberRow(), MembersFixtures.viewerRow()],
                    memberCount: 3
                )))
            }
        case .removeMember:
            if let error {
                sut.members.enqueueRemoveMember(.failure(error), held: held)
            } else {
                sut.members.enqueueRemoveMember(.success(()), held: held)
                sut.lists.enqueueFetchListDetail(.success(try MemberServiceHarness.detail(
                    roster: [MembersFixtures.ownerRow()], memberCount: 1
                )))
            }
        case .leaveList:
            if let error {
                sut.members.enqueueRemoveMember(.failure(error), held: held)
            } else {
                sut.members.enqueueRemoveMember(.success(()), held: held)
            }
        case .setCoOwner:
            if let error {
                sut.lists.enqueueUpdateList(.failure(error), held: held)
            } else {
                sut.lists.enqueueUpdateList(.success(try MemberServiceHarness.detail()), held: held)
            }
        }
    }

    /// Runs the operation against the loaded list; a thrown error is swallowed (tests assert on
    /// service state).
    @MainActor
    func run(_ sut: MemberServiceHarness) async {
        _ = try? await runThrowing(sut)
    }

    @MainActor
    func runThrowing(_ sut: MemberServiceHarness) async throws {
        let id = MemberServiceHarness.listId
        switch self {
        case .addMember:
            try await sut.service.addMember(listId: id, MemberServiceHarness.addInput)
        case .removeMember:
            try await sut.service.removeMember(listId: id, userId: MembersFixtures.memberUserId)
        case .leaveList:
            try await sut.service.leaveList(id: id, userId: Self.leaveUserId)
        case .setCoOwner:
            try await sut.service.setCoOwner(listId: id, email: MembersFixtures.coOwnerEmail)
        }
    }

    /// Waits until the operation's held first call has entered its repository.
    @MainActor
    func awaitHeld(_ sut: MemberServiceHarness) async {
        switch self {
        case .addMember, .removeMember, .leaveList:
            await sut.members.gate.nextHeldCall()
        case .setCoOwner:
            await sut.lists.nextHeldCall()
        }
    }

    @MainActor
    func releaseAll(_ sut: MemberServiceHarness) {
        sut.members.gate.releaseAll()
        sut.lists.releaseAll()
    }
}
