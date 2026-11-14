//
//  ListServiceMutationPublishesNothingTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2: a ListService MUTATION that fails throws the typed error to the initiating view and
//  publishes nothing. In particular it neither sets nor clears nor replaces the two scoped load
//  failures (listsLoadFailure for the dashboard, detailLoadFailure for the detail screen), so one
//  screen can never show an error produced by another screen's action.
//
//  Every mutation is covered: createList, updateList, removeCoOwner, deleteList, addMember,
//  removeMember, leaveList and setCoOwner.
//
//  Determinism: gated fakes; nothing is held here. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The eight ListService mutations. `script` queues one failing step; `run` performs the call.
nonisolated enum ListMutation: CaseIterable, Sendable, CustomTestStringConvertible {
    case createList, updateList, removeCoOwner, deleteList, addMember, removeMember, leaveList, setCoOwner

    var testDescription: String {
        switch self {
        case .createList: "createList"
        case .updateList: "updateList"
        case .removeCoOwner: "removeCoOwner"
        case .deleteList: "deleteList"
        case .addMember: "addMember"
        case .removeMember: "removeMember"
        case .leaveList: "leaveList"
        case .setCoOwner: "setCoOwner"
        }
    }

    @MainActor
    func script(_ sut: MemberServiceHarness, failing error: ListError) {
        switch self {
        case .createList: sut.lists.enqueueCreateList(.failure(error))
        case .updateList, .setCoOwner: sut.lists.enqueueUpdateList(.failure(error))
        case .removeCoOwner: sut.lists.enqueueRemoveCoOwner(.failure(error))
        case .deleteList: sut.lists.enqueueDeleteList(.failure(error))
        case .addMember: sut.members.enqueueAddMember(.failure(error))
        case .removeMember, .leaveList: sut.members.enqueueRemoveMember(.failure(error))
        }
    }

    @MainActor
    func run(_ sut: MemberServiceHarness) async throws {
        let id = MemberServiceHarness.listId
        switch self {
        case .createList:
            try await sut.service.createList(
                CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)
            )
        case .updateList:
            try await sut.service.updateList(id: id, UpdateListInput(name: "X", theme: nil, visibility: nil))
        case .removeCoOwner:
            try await sut.service.removeCoOwner(listId: id)
        case .deleteList:
            try await sut.service.deleteList(id: id)
        case .addMember:
            try await sut.service.addMember(listId: id, MemberServiceHarness.addInput)
        case .removeMember:
            try await sut.service.removeMember(listId: id, userId: MembersFixtures.memberUserId)
        case .leaveList:
            try await sut.service.leaveList(id: id, userId: "user-me")
        case .setCoOwner:
            try await sut.service.setCoOwner(listId: id, email: MembersFixtures.coOwnerEmail)
        }
    }
}

@Suite("ListService mutations publish nothing", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceMutationPublishesNothingTests {

    private typealias H = MemberServiceHarness

    /// A loaded service that already holds BOTH load failures (lists: network, detail: server), so a
    /// mutation that sets, clears or replaces either of them is caught.
    private func makeSUT() async throws -> MemberServiceHarness {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        sut.lists.enqueueFetchLists(.failure(ListError.network))
        await sut.service.refreshLists()
        sut.lists.enqueueFetchListDetail(.failure(ListError.server))
        await sut.service.loadListDetail(id: H.listId)
        return sut
    }

    @Test("a failing mutation throws the typed error and leaves both existing load failures untouched",
          arguments: ListMutation.allCases)
    func failureThrowsAndLeavesLoadFailuresUntouched(op: ListMutation) async throws {
        let sut = try await makeSUT()
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        #expect(sut.service.detailLoadFailure == .server, "precondition")
        op.script(sut, failing: .forbidden)

        await #expect(throws: ListError.forbidden) {
            try await op.run(sut)
        }

        #expect(sut.service.listsLoadFailure == .network, "a mutation must not replace or clear the lists failure")
        #expect(sut.service.detailLoadFailure == .server, "a mutation must not replace or clear the detail failure")
        #expect(sut.service.isMutating == false)
    }

    @Test("a failing mutation sets no load failure on a service that has none",
          arguments: ListMutation.allCases, [ListError.network, .server, .rateLimited(retryAfter: 3), .validation(message: "Invalid input")])
    func failureSetsNoLoadFailure(op: ListMutation, error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        op.script(sut, failing: error)

        await #expect(throws: error) {
            try await op.run(sut)
        }

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a mutation that is rejected as notFound still throws it and publishes nothing",
          arguments: [ListMutation.updateList, .removeCoOwner, .addMember, .removeMember, .setCoOwner])
    func notFoundThrowsAndPublishesNothing(op: ListMutation) async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        op.script(sut, failing: .notFound)

        await #expect(throws: ListError.notFound) {
            try await op.run(sut)
        }

        #expect(sut.service.goneListId == H.listId, "the existing gone-list handling is unchanged")
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a mutation cancelled by the repository publishes nothing", arguments: ListMutation.allCases)
    func cancellationPublishesNothing(op: ListMutation) async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        switch op {
        case .createList: sut.lists.enqueueCreateList(.failure(CancellationError()))
        case .updateList, .setCoOwner: sut.lists.enqueueUpdateList(.failure(CancellationError()))
        case .removeCoOwner: sut.lists.enqueueRemoveCoOwner(.failure(CancellationError()))
        case .deleteList: sut.lists.enqueueDeleteList(.failure(CancellationError()))
        case .addMember: sut.members.enqueueAddMember(.failure(CancellationError()))
        case .removeMember, .leaveList: sut.members.enqueueRemoveMember(.failure(CancellationError()))
        }

        _ = try? await op.run(sut)

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }
}
