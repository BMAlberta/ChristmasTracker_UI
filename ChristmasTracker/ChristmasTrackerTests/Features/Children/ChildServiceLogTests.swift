//
//  ChildServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch B: the step lines ChildService writes through ServiceLog for the load, add and
//  delete: started and processed on success, exactly one error on failure, cancelled (never an
//  error) when the session ends, only the failure line in a Release-style run, and no secret
//  fixture (a child's name) in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceLogTests {

    private struct Rig {
        let service: ChildService
        let repo: GatedChildRepository
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let repo = GatedChildRepository()
        repo.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        return Rig(service: ChildService(repository: repo, log: log), repo: repo, sink: sink)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    private func input(_ name: String = "Eli") -> CreateChildInput {
        CreateChildInput(firstName: name, lastName: "Example", displayName: nil, relationship: .guardian)
    }

    @Test("a load logs started, then processed with a count")
    func loadSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))

        await rig.service.loadChildren()

        #expect(messages(rig) == ["load children started", "load children processed (2 children)"])
    }

    @Test("a failed load logs exactly one error line")
    func loadFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchChildren(.failure(ChildError.network))

        await rig.service.loadChildren()

        #expect(errors(rig) == ["load children failed"])
        #expect(messages(rig) == ["load children started", "load children failed"])
    }

    @Test("a load whose session ends logs cancelled and no error")
    func loadCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchChildren(.success([]), held: true)
        let task = Task { @MainActor in await rig.service.loadChildren() }
        await rig.repo.gate.nextHeldCall()

        try await rig.service.clearForSession()
        await task.value

        #expect(messages(rig) == ["load children started", "load children cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("add and delete log started then processed")
    func mutationSuccess() async throws {
        let rig = makeRig()
        rig.repo.enqueueCreateChild(.success(ChildFixtures.child(id: "child-9")))
        rig.repo.enqueueDeleteChild(.success(()))

        try await rig.service.addChild(input())
        try await rig.service.deleteChild(id: "child-9")

        #expect(messages(rig) == [
            "add child started", "add child processed", "delete child started", "delete child processed"
        ])
    }

    @Test("a failed add and a failed delete each log exactly one error line")
    func mutationFailure() async {
        let rig = makeRig()
        rig.repo.enqueueCreateChild(.failure(ChildError.server))
        rig.repo.enqueueDeleteChild(.failure(ChildError.server))

        await #expect(throws: ChildError.self) { try await rig.service.addChild(input()) }
        await #expect(throws: ChildError.self) { try await rig.service.deleteChild(id: "child-1") }

        #expect(errors(rig) == ["add child failed", "delete child failed"])
    }

    @Test("a session that ends mid-add logs cancelled and no error")
    func addCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueCreateChild(.success(ChildFixtures.child()), held: true)
        let task = startOutcome { try await rig.service.addChild(input()) }
        await rig.repo.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(messages(rig) == ["add child started", "add child cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a session that ends mid-delete logs cancelled and no error")
    func deleteCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueDeleteChild(.success(()), held: true)
        let task = startOutcome { try await rig.service.deleteChild(id: "child-1") }
        await rig.repo.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(messages(rig) == ["delete child started", "delete child cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async {
        let rig = makeRig(verbose: false)
        rig.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        rig.repo.enqueueFetchChildren(.failure(ChildError.server))

        await rig.service.loadChildren()
        #expect(rig.sink.lines.isEmpty)

        await rig.service.loadChildren()
        #expect(messages(rig) == ["load children failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("a child's name never appears in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let secret = ChildFixtures.child(
            id: "ZZ-secret-id", firstName: "ZZ-secret-name", lastName: "zz-secret@example.com"
        )
        rig.repo.enqueueFetchChildren(.success([secret]))
        rig.repo.enqueueCreateChild(.success(secret))
        rig.repo.enqueueDeleteChild(.failure(ChildError.server))

        await rig.service.loadChildren()
        try await rig.service.addChild(input("ZZ-secret-name"))
        try? await rig.service.deleteChild(id: "ZZ-secret-id")

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-"))
            #expect(!line.message.contains("zz-secret"))
        }
    }
}
