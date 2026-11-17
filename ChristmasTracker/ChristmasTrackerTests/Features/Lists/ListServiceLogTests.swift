//
//  ListServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch C: the step lines ListService writes through ServiceLog. For the lists load, the
//  pull-to-refresh refresh, the detail load and refresh, the mutations, the fresh fetch, the batch archive
//  and the member changes: started (with the refresh reason) and processed on success, exactly one error on
//  failure, cancelled (never an error) when the caller is cancelled, the skipped line while a refresh is in
//  flight (and no second repository call), only the failure line in a Release-style run, and no secret
//  fixture in any line.
//
//  Determinism: gated fakes with the nextHeldCall() handshake; no sleeps.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceLogTests {

    private struct Rig {
        let service: ListService
        let repo: GatedListRepository
        let members: GatedMemberRepository
        let sink: CapturingOperationLog
    }

    private struct SecretError: Error, CustomStringConvertible {
        var description: String { "ZZ-secret-list zz-secret@example.com 987654.32" }
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let repo = GatedListRepository()
        repo.honorsCancellation = honorsCancellation
        let members = GatedMemberRepository()
        members.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        let service = ListService(
            repository: repo, memberRepository: members, dataStore: ListDataStore(), log: log
        )
        return Rig(service: service, repo: repo, members: members, sink: sink)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    private func list(_ id: String, name: String = "Name of list") -> GiftList {
        ListFixtures.giftList(id: id, name: name)
    }

    private var createInput: CreateListInput {
        CreateListInput(recipientId: "user-1", year: 2026, name: "ZZ-secret-list", theme: nil, visibility: .private)
    }

    private var updateInput: UpdateListInput {
        UpdateListInput(name: "ZZ-secret-list", theme: nil, visibility: nil)
    }

    // MARK: - loadLists

    @Test("a load logs started with its reason, then processed with a count")
    func loadSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))

        await rig.service.loadLists(reason: .appear)

        #expect(messages(rig) == ["load lists started (appear)", "load lists processed (2 lists)"])
    }

    @Test("a failed load logs exactly one error line")
    func loadFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.failure(ListError.network))

        await rig.service.loadLists(reason: .appear)

        #expect(errors(rig) == ["load lists failed"])
        #expect(messages(rig) == ["load lists started (appear)", "load lists failed"])
    }

    @Test("a cancelled load logs cancelled and no error")
    func loadCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let task = Task { @MainActor in await rig.service.loadLists(reason: .appear) }
        await rig.repo.nextHeldCall()

        task.cancel()
        await task.value

        #expect(messages(rig) == ["load lists started (appear)", "load lists cancelled"])
        #expect(errors(rig).isEmpty)
    }

    // MARK: - refreshLists (the pull-to-refresh entry point)

    @Test("a pull refresh logs started (pull), then processed with a count")
    func refreshSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))

        await rig.service.refreshLists(reason: .pull)

        #expect(messages(rig) == ["refresh lists started (pull)", "refresh lists processed (2 lists)"])
    }

    @Test("a refresh without a caller reason says unspecified")
    func refreshDefaultReason() async {
        let rig = makeRig()

        await rig.service.refreshLists()

        #expect(messages(rig).first == "refresh lists started (unspecified)")
    }

    @Test("a refresh while one is in flight logs skipped and makes no second repository call")
    func refreshSkippedWhileRefreshing() async {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let first = Task { @MainActor in await rig.service.refreshLists(reason: .pull) }
        await rig.repo.nextHeldCall()

        await rig.service.refreshLists(reason: .pull)

        #expect(messages(rig) == ["refresh lists started (pull)", "refresh lists skipped (already refreshing)"])
        #expect(rig.repo.fetchListsCount == 1, "the skipped refresh made no second call")
        rig.repo.releaseAll()
        await first.value
        #expect(messages(rig).last == "refresh lists processed (1 lists)")
        #expect(errors(rig).isEmpty)
    }

    @Test("a refresh cancelled while its request runs logs cancelled, no error, and stores no failure")
    func refreshCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let task = Task { @MainActor in await rig.service.refreshLists(reason: .pull) }
        await rig.repo.nextHeldCall()

        task.cancel()
        let failure = await task.value

        #expect(failure == nil)
        #expect(rig.service.listsLoadFailure == nil)
        #expect(messages(rig) == ["refresh lists started (pull)", "refresh lists cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a refresh cancelled before its request is made logs cancelled and no error")
    func refreshCancelledBeforeRequest() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchLists(.failure(CancellationError()))

        let failure = await rig.service.refreshLists(reason: .pull)

        #expect(failure == nil)
        #expect(messages(rig) == ["refresh lists started (pull)", "refresh lists cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a failed refresh logs exactly one error line")
    func refreshFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.failure(ListError.server))

        let failure = await rig.service.refreshLists(reason: .pull)

        #expect(failure == .server)
        #expect(errors(rig) == ["refresh lists failed"])
    }

    @Test("a stale cached load runs the refresh and logs its own started line with the reason")
    func loadWithStaleCacheRefreshes() async {
        let rig = makeRig()
        let store = ListDataStore()
        await store.setLists([list("list-a")])
        let log = ServiceLog(sink: rig.sink, verbosity: LogVerbosity(isVerbose: true))
        let service = ListService(repository: rig.repo, dataStore: store, log: log)
        rig.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        let shouldRefresh = await store.shouldRefresh()

        await service.loadLists(reason: .tab)

        let lines = messages(rig)
        #expect(lines.first == "load lists started (tab)")
        #expect(lines.contains("load lists processed (1 lists)"))
        if shouldRefresh {
            #expect(lines.contains("refresh lists started (tab)"))
        } else {
            #expect(!lines.contains { $0.hasPrefix("refresh lists") })
        }
        #expect(errors(rig).isEmpty)
    }

    // MARK: - Detail

    @Test("a detail load and a detail refresh log started with the reason, then processed")
    func detailSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a")))
        rig.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a")))

        await rig.service.loadListDetail(id: "list-a", reason: .appear)
        let failure = await rig.service.refreshListDetail(id: "list-a", reason: .pull)

        #expect(failure == nil)
        #expect(messages(rig) == [
            "load list details started (appear)", "load list details processed",
            "refresh list details started (pull)", "refresh list details processed"
        ])
    }

    @Test("a failed detail load and a failed detail refresh each log exactly one error line")
    func detailFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchListDetail(.failure(ListError.network))
        rig.repo.enqueueFetchListDetail(.failure(ListError.network))

        await rig.service.loadListDetail(id: "list-a")
        _ = await rig.service.refreshListDetail(id: "list-a")

        #expect(errors(rig) == ["load list details failed", "refresh list details failed"])
    }

    @Test("a cancelled detail load and a cancelled detail refresh log cancelled and no error")
    func detailCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a")), held: true)
        rig.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a")), held: true)
        let load = Task { @MainActor in await rig.service.loadListDetail(id: "list-a", reason: .appear) }
        await rig.repo.nextHeldCall()
        load.cancel()
        await load.value
        let refresh = Task { @MainActor in await rig.service.refreshListDetail(id: "list-a", reason: .pull) }
        await rig.repo.nextHeldCall()
        refresh.cancel()
        _ = await refresh.value

        #expect(messages(rig) == [
            "load list details started (appear)", "load list details cancelled",
            "refresh list details started (pull)", "refresh list details cancelled"
        ])
        #expect(errors(rig).isEmpty)
    }

    // MARK: - Mutations

    @Test("create, update and archive log started then processed")
    func mutationSuccess() async throws {
        let rig = makeRig()
        rig.repo.enqueueCreateList(.success(ListFixtures.listDetail(id: "list-new")))
        rig.repo.enqueueUpdateList(.success(ListFixtures.listDetail(id: "list-new")))
        rig.repo.enqueueDeleteList(.success(()))
        rig.repo.enqueueFetchLists(.success([]))

        try await rig.service.createList(createInput)
        try await rig.service.updateList(id: "list-new", updateInput)
        try await rig.service.deleteList(id: "list-new")

        #expect(messages(rig) == [
            "create list started", "create list processed",
            "update list started", "update list processed",
            "archive list started", "archive list processed"
        ])
    }

    @Test("a failed create, update, archive and co-owner removal each log exactly one error line")
    func mutationFailure() async {
        let rig = makeRig()
        rig.repo.enqueueCreateList(.failure(ListError.server))
        rig.repo.enqueueUpdateList(.failure(ListError.server))
        rig.repo.enqueueDeleteList(.failure(ListError.server))
        rig.repo.enqueueRemoveCoOwner(.failure(SecretError()))

        await #expect(throws: ListError.self) { try await rig.service.createList(createInput) }
        await #expect(throws: ListError.self) { try await rig.service.updateList(id: "list-a", updateInput) }
        await #expect(throws: ListError.self) { try await rig.service.deleteList(id: "list-a") }
        await #expect(throws: ListError.self) { try await rig.service.removeCoOwner(listId: "list-a") }

        #expect(errors(rig) == [
            "create list failed", "update list failed", "archive list failed", "remove co-owner failed"
        ])
    }

    @Test("a cancelled create logs cancelled and no error")
    func createCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueCreateList(.success(ListFixtures.listDetail(id: "list-new")), held: true)
        let input = createInput
        let task = startOutcome { try await rig.service.createList(input) }
        await rig.repo.nextHeldCall()

        task.cancel()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(messages(rig) == ["create list started", "create list cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a session that ends mid-archive logs cancelled and no error")
    func archiveSessionEnd() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueDeleteList(.success(()), held: true)
        let task = startOutcome { try await rig.service.deleteList(id: "list-a") }
        await rig.repo.nextHeldCall()

        try await rig.service.clearForSession()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(messages(rig) == ["archive list started", "archive list cancelled"])
        #expect(errors(rig).isEmpty)
    }

    // MARK: - freshLists

    @Test("a fresh fetch logs started then processed with a count")
    func freshSuccess() async throws {
        let rig = makeRig()
        rig.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))

        let fetched = try await rig.service.freshLists()

        #expect(fetched.count == 2)
        #expect(messages(rig) == ["fresh lists started", "fresh lists processed (2 lists)"])
    }

    @Test("a failed fresh fetch logs one error; a cancelled one logs cancelled and no error")
    func freshFailureAndCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchLists(.failure(ListError.server))
        await #expect(throws: ListError.self) { try await rig.service.freshLists() }
        #expect(errors(rig) == ["fresh lists failed"])

        rig.repo.enqueueFetchLists(.success([]), held: true)
        let task = startOutcome { _ = try await rig.service.freshLists() }
        await rig.repo.nextHeldCall()
        task.cancel()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(errors(rig) == ["fresh lists failed"], "the cancel added no error")
        #expect(messages(rig).last == "fresh lists cancelled")
    }

    // MARK: - archiveLists (one line per operation, nothing per list)

    @Test("a batch archive of three lists logs one started and one processed with the count")
    func batchSuccess() async {
        let rig = makeRig()
        for _ in 0..<3 { rig.repo.enqueueDeleteList(.success(())) }
        rig.repo.enqueueFetchLists(.success([]))

        let result = await rig.service.archiveLists(ids: ["a", "b", "c"])

        #expect(result.archivedCount == 3)
        #expect(messages(rig).filter { $0.hasPrefix("archive list in batch") } == [
            "archive list in batch started", "archive list in batch processed (3 lists)"
        ])
        #expect(errors(rig).isEmpty)
    }

    @Test("a batch that stops at a failure logs one processed with the count and exactly one failed line")
    func batchFailure() async {
        let rig = makeRig()
        rig.repo.enqueueDeleteList(.success(()))
        rig.repo.enqueueDeleteList(.failure(ListError.server))
        rig.repo.enqueueFetchLists(.success([]))

        let result = await rig.service.archiveLists(ids: ["a", "b", "c"])

        #expect(result.archivedCount == 1)
        #expect(result.failedId == "b")
        #expect(rig.repo.deleteListCount == 2)
        #expect(messages(rig) == [
            "archive list in batch started", "archive list in batch processed (1 lists)",
            "archive list in batch failed"
        ])
        #expect(errors(rig) == ["archive list in batch failed"])
    }

    @Test("a not-found in a batch counts as archived and logs no error")
    func batchNotFound() async {
        let rig = makeRig()
        rig.repo.enqueueDeleteList(.failure(ListError.notFound))
        rig.repo.enqueueFetchLists(.success([]))

        _ = await rig.service.archiveLists(ids: ["a"])

        #expect(messages(rig) == ["archive list in batch started", "archive list in batch processed (1 lists)"])
    }

    @Test("a failed reload after the batch logs its own single error line")
    func batchReloadFailure() async {
        let rig = makeRig()
        rig.repo.enqueueDeleteList(.success(()))
        rig.repo.enqueueFetchLists(.failure(ListError.network))

        _ = await rig.service.archiveLists(ids: ["a"])

        #expect(errors(rig) == ["reload lists after archive batch failed"])
    }

    @Test("a batch cancelled between archives logs cancelled and no error")
    func batchCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueDeleteList(.success(()), held: true)
        let task = Task { @MainActor in await rig.service.archiveLists(ids: ["a", "b"]) }
        await rig.repo.nextHeldCall()

        task.cancel()
        let result = await task.value

        #expect(result.archivedCount == 0)
        #expect(messages(rig) == ["archive list in batch started", "archive list in batch cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("an empty batch makes no call and logs nothing")
    func batchEmpty() async {
        let rig = makeRig()

        _ = await rig.service.archiveLists(ids: [])

        #expect(rig.sink.lines.isEmpty)
    }

    // MARK: - Members

    @Test("remove member logs started then processed; a failed add logs exactly one error")
    func memberLines() async throws {
        let rig = makeRig()
        rig.members.enqueueRemoveMember(.success(()))
        rig.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a")))
        rig.members.enqueueAddMember(.failure(ListError.alreadyMember))
        rig.members.enqueueRemoveMember(.success(()))

        try await rig.service.removeMember(listId: "list-a", userId: "user-2")
        let input = AddMemberInput(email: "zz-secret@example.com", role: .member)
        await #expect(throws: ListError.self) { try await rig.service.addMember(listId: "list-a", input) }
        try await rig.service.leaveList(id: "list-a", userId: "user-1")

        #expect(messages(rig) == [
            "remove member started", "remove member processed",
            "add member started", "add member failed",
            "leave list started", "leave list processed"
        ])
        #expect(errors(rig) == ["add member failed"])
    }

    @Test("a cancelled member removal logs cancelled and no error")
    func memberCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.members.enqueueRemoveMember(.success(()), held: true)
        let task = startOutcome { try await rig.service.removeMember(listId: "list-a", userId: "user-2") }
        await rig.members.gate.nextHeldCall()

        task.cancel()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(messages(rig) == ["remove member started", "remove member cancelled"])
        #expect(errors(rig).isEmpty)
    }

    // MARK: - Release-style and secrets

    @Test("a Release-style run logs only the failure lines")
    func nonVerbose() async throws {
        let rig = makeRig(verbose: false)
        rig.repo.enqueueFetchLists(.success([list("list-a")]))
        rig.repo.enqueueFetchLists(.failure(ListError.server))
        rig.repo.enqueueCreateList(.success(ListFixtures.listDetail(id: "list-new")))

        await rig.service.loadLists(reason: .appear)
        _ = await rig.service.refreshLists(reason: .pull)
        _ = await rig.service.refreshLists(reason: .pull)
        try await rig.service.createList(createInput)

        #expect(messages(rig) == ["refresh lists failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("a Release-style skipped refresh logs nothing")
    func nonVerboseSkipped() async {
        let rig = makeRig(verbose: false)
        rig.repo.enqueueFetchLists(.success([]), held: true)
        let first = Task { @MainActor in await rig.service.refreshLists(reason: .pull) }
        await rig.repo.nextHeldCall()

        await rig.service.refreshLists(reason: .pull)
        rig.repo.releaseAll()
        await first.value

        #expect(rig.sink.lines.isEmpty)
    }

    @Test("a list name, member email, price and error text never appear in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let secretName = "ZZ-secret-list 987654.32"
        rig.repo.enqueueFetchLists(.success([list("ZZ-secret-id", name: secretName)]))
        rig.repo.enqueueFetchLists(.failure(SecretError()))
        rig.repo.enqueueFetchListDetail(.failure(SecretError()))
        rig.repo.enqueueCreateList(.success(ListFixtures.listDetail(id: "ZZ-secret-id", name: secretName)))
        rig.repo.enqueueUpdateList(.failure(SecretError()))
        rig.repo.enqueueDeleteList(.failure(SecretError()))
        rig.members.enqueueAddMember(.failure(SecretError()))

        await rig.service.loadLists(reason: .appear)
        _ = await rig.service.refreshLists(reason: .pull)
        await rig.service.loadListDetail(id: "ZZ-secret-id")
        try await rig.service.createList(createInput)
        try? await rig.service.updateList(id: "ZZ-secret-id", updateInput)
        _ = await rig.service.archiveLists(ids: ["ZZ-secret-id"])
        let input = AddMemberInput(email: "zz-secret@example.com", role: .member)
        try? await rig.service.addMember(listId: "ZZ-secret-id", input)

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
        }
    }
}
