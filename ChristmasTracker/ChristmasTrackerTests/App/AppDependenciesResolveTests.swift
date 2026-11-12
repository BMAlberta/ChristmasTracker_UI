//
//  AppDependenciesResolveTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: AppDependencies.resolve(mode:generatedClient:reporter:) never falls back to a
//  mock when real mode has no client. In that case the repositories are inert (every call throws
//  ConfigurationError.clientUnavailable, no data) and exactly one category-only report is made.
//
//  The client for the "real mode with a client" case is built with the real factory and a fake
//  transport, the same way GeneratedClientListRepositoryTests does. No network.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import Testing
@testable import ChristmasTracker

/// Records bootstrap failure reports. Fake, MainActor like the app default.
@MainActor
final class RecordingBootstrapReporter: BootstrapFailureReporting {
    private(set) var categories: [String] = []

    func reportClientUnavailable(category: String) {
        categories.append(category)
    }
}

@Suite("AppDependencies.resolve Tests", .timeLimit(.minutes(1)))
@MainActor
struct AppDependenciesResolveTests {

    // MARK: - Factory

    private struct SUT {
        let state: BootstrapState
        let dependencies: AppDependencies
        let reporter: RecordingBootstrapReporter
    }

    private func makeSUT(mode: APIMode, withClient: Bool) throws -> SUT {
        let reporter = RecordingBootstrapReporter()
        var client: (any APIProtocol)?
        if withClient {
            let url = try #require(URL(string: "https://api.example.com"))
            client = try TrackerClientFactory.make(
                serverURL: url,
                info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
                tokenProvider: ListFakeTokenProvider(token: nil),
                sessionRefresher: ListFakeRefresher(),
                versionOutdatedHandler: ListFakeVersionHandler(),
                transport: ListFakeTransport()
            )
        }
        let result = AppDependencies.resolve(mode: mode, generatedClient: client, reporter: reporter)
        return SUT(state: result.state, dependencies: result.dependencies, reporter: reporter)
    }

    // MARK: - Real mode, no client

    @Test("real mode without a client is failed and reports exactly once with the category only")
    func failedReportsOnce() throws {
        let sut = try makeSUT(mode: .real, withClient: false)

        #expect(sut.state == .failed)
        #expect(sut.reporter.categories == ["client_unavailable"])
    }

    @Test("real mode without a client builds no Mock repository")
    func failedBuildsNoMocks() throws {
        let deps = try makeSUT(mode: .real, withClient: false).dependencies

        #expect(!(deps.authRepository is MockAuthenticationRepository))
        #expect(!(deps.listRepository is MockListRepository))
        #expect(!(deps.itemRepository is MockItemRepository))
        // EDITED (I3c-C): also no generated item repository without a client.
        #expect(!(deps.itemRepository is GeneratedClientItemRepository))
        #expect(!(deps.authRepository is GeneratedClientAuthenticationRepository))
        #expect(!(deps.listRepository is GeneratedClientListRepository))
    }

    @Test("real mode without a client: every list call throws clientUnavailable")
    func failedListRepositoryThrows() async throws {
        let repo = try makeSUT(mode: .real, withClient: false).dependencies.listRepository

        await #expect(throws: ConfigurationError.clientUnavailable) { _ = try await repo.fetchLists() }
        await #expect(throws: ConfigurationError.clientUnavailable) { _ = try await repo.fetchListDetail(id: "list-a") }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.createList(
                CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)
            )
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }
        await #expect(throws: ConfigurationError.clientUnavailable) { try await repo.deleteList(id: "list-a") }
    }

    @Test("real mode without a client: every auth call throws clientUnavailable")
    func failedAuthRepositoryThrows() async throws {
        let repo = try makeSUT(mode: .real, withClient: false).dependencies.authRepository

        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.login(email: "user@example.com", password: "not-a-real-password")
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.register(
                email: "user@example.com", password: "not-a-real-password",
                firstName: "Test", lastName: "User", registrationCode: "CODE"
            )
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.refresh(refreshToken: "refresh-FAKE")
        }
        await #expect(throws: ConfigurationError.clientUnavailable) { try await repo.logout() }
    }

    @Test("real mode without a client: item calls throw clientUnavailable")
    func failedItemRepositoryThrows() async throws {
        let repo = try makeSUT(mode: .real, withClient: false).dependencies.itemRepository

        await #expect(throws: ConfigurationError.clientUnavailable) { _ = try await repo.fetchItems(listId: "list-a") }
        await #expect(throws: ConfigurationError.clientUnavailable) { _ = try await repo.fetchItemDetail(id: "item-a") }
        await #expect(throws: ConfigurationError.clientUnavailable) { try await repo.deleteItem(id: "item-a") }
        // EDITED (I3c-C): create and update take CreateItemInput / UpdateItemInput now; also covered.
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.createItem(
                listId: "list-a",
                CreateItemInput(
                    name: "N", description: "D", url: nil, imageUrl: nil,
                    expectedUnitPrice: nil, quantityRequested: 1, priority: 5
                )
            )
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.updateItem(id: "item-a", UpdateItemInput(name: "X"))
        }
    }

    // MARK: - I3c-C: item repository identity

    @Test("real mode without a client builds the inert item repository, no Mock and no generated one")
    func failedBuildsInertItemRepository() throws {
        let deps = try makeSUT(mode: .real, withClient: false).dependencies

        #expect(deps.itemRepository is InertItemRepository)
        #expect(!(deps.itemRepository is MockItemRepository))
        #expect(!(deps.itemRepository is GeneratedClientItemRepository))
    }

    @Test("real mode with a client builds the generated-client item repository and no Mock item repository")
    func realModeBuildsGeneratedItemRepository() throws {
        let deps = try makeSUT(mode: .real, withClient: true).dependencies

        #expect(deps.itemRepository is GeneratedClientItemRepository)
        #expect(!(deps.itemRepository is MockItemRepository), "the real branch must not build any Mock item repository")
        #expect(!(deps.itemRepository is InertItemRepository))
    }

    @Test("mock mode builds the Mock item repository, not the generated or inert one")
    func mockModeBuildsMockItemRepository() throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies

        #expect(deps.itemRepository is MockItemRepository)
        #expect(!(deps.itemRepository is GeneratedClientItemRepository))
        #expect(!(deps.itemRepository is InertItemRepository))
    }

    @Test("mock mode: the item mock follows the list mock's flags (a viewer list refuses create, an owner list accepts it)")
    func mockModeItemRepositoryFollowsTheListMockFlags() async throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies
        let items = try #require(deps.itemRepository as? MockItemRepository)
        await items.setDelay(0)
        let input = CreateItemInput(
            name: "N", description: "D", url: nil, imageUrl: nil,
            expectedUnitPrice: nil, quantityRequested: 1, priority: 5
        )

        await #expect(throws: ItemError.forbidden) {
            _ = try await items.createItem(listId: MockListData.viewerMemberList.id, input)
        }
        let onMemberList = try await items.createItem(listId: MockListData.memberList.id, input)
        let onOwnerList = try await items.createItem(listId: MockListData.ownerOfChildList.id, input)

        #expect(onMemberList.offList == true, "a MEMBER adds an off-list item")
        #expect(onOwnerList.offList == false, "an owner adds a regular item")
    }

    @Test("mock mode: a list id the list mock does not know falls back to the default owner flags")
    func mockModeItemRepositoryUnknownListFallsBack() async throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies
        let items = try #require(deps.itemRepository as? MockItemRepository)
        await items.setDelay(0)

        let created = try await items.createItem(
            listId: "list-not-in-the-list-mock",
            CreateItemInput(
                name: "N", description: "D", url: nil, imageUrl: nil,
                expectedUnitPrice: nil, quantityRequested: 1, priority: 5
            )
        )

        #expect(created.offList == false)
    }

    // MARK: - Mock mode

    @Test("mock mode is ready with the Mock repositories and reports nothing")
    func mockModeIsReady() throws {
        let sut = try makeSUT(mode: .mock, withClient: false)

        #expect(sut.state == .ready)
        #expect(sut.dependencies.authRepository is MockAuthenticationRepository)
        #expect(sut.dependencies.listRepository is MockListRepository)
        #expect(sut.dependencies.itemRepository is MockItemRepository)
        #expect(sut.reporter.categories.isEmpty)
    }

    // MARK: - Real mode with a client

    @Test("real mode with a client is ready with the generated-client repositories and reports nothing")
    func realModeWithClientIsReady() throws {
        let sut = try makeSUT(mode: .real, withClient: true)

        #expect(sut.state == .ready)
        #expect(sut.dependencies.listRepository is GeneratedClientListRepository)
        #expect(sut.dependencies.authRepository is GeneratedClientAuthenticationRepository)
        #expect(!(sut.dependencies.listRepository is MockListRepository))
        #expect(!(sut.dependencies.authRepository is MockAuthenticationRepository))
        #expect(sut.reporter.categories.isEmpty)
    }

    // MARK: - I3b-M2: member and child repositories

    @Test("mock mode builds MockMemberRepository and MockChildRepository")
    func mockModeBuildsMemberAndChildMocks() throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies

        #expect(deps.memberRepository is MockMemberRepository)
        #expect(deps.childRepository is MockChildRepository)
    }

    @Test("mock mode: the member repository shares the list repository's state (a leave removes the list)")
    func mockModeMemberRepositoryHasTheSameListRepository() async throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies
        let lists = try #require(deps.listRepository as? MockListRepository)
        await lists.setDelay(0)
        let before = try await deps.listRepository.fetchLists()
        let leavable = try #require(before.first(where: { $0.capabilities.canLeaveList }), "precondition: a list the user may leave")

        try await deps.memberRepository.removeMember(listId: leavable.id, userId: MockListData.currentUser.id)

        let after = try await deps.listRepository.fetchLists()
        #expect(after.contains(where: { $0.id == leavable.id }) == false,
                "the member mock must work on the SAME MockListRepository instance as deps.listRepository")
    }

    @Test("mock mode: the child repository shares the list repository's state (a list for a new child is not blind)")
    func mockModeChildRepositoryHasTheSameListRepository() async throws {
        let deps = try makeSUT(mode: .mock, withClient: false).dependencies
        let lists = try #require(deps.listRepository as? MockListRepository)
        await lists.setDelay(0)
        let child = try await deps.childRepository.createChild(
            CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .parent)
        )

        let detail = try await deps.listRepository.createList(
            CreateListInput(recipientId: child.id, year: 2031, name: "Eli's Wishes", theme: nil, visibility: .private)
        )

        #expect(detail.recipient.id == child.id)
        #expect(detail.capabilities.canSeeGiftActivity)
        #expect(detail.itemCount != nil)
    }

    @Test("real mode with a client builds the generated-client member and child repositories")
    func realModeBuildsGeneratedMemberAndChildRepositories() throws {
        let deps = try makeSUT(mode: .real, withClient: true).dependencies

        #expect(deps.memberRepository is GeneratedClientMemberRepository)
        #expect(deps.childRepository is GeneratedClientChildRepository)
        #expect(!(deps.memberRepository is MockMemberRepository))
        #expect(!(deps.childRepository is MockChildRepository))
    }

    @Test("real mode without a client builds inert member and child repositories and no Mock")
    func failedBuildsInertMemberAndChildRepositories() throws {
        let deps = try makeSUT(mode: .real, withClient: false).dependencies

        #expect(deps.memberRepository is InertMemberRepository)
        #expect(deps.childRepository is InertChildRepository)
        #expect(!(deps.memberRepository is MockMemberRepository))
        #expect(!(deps.childRepository is MockChildRepository))
        #expect(!(deps.memberRepository is GeneratedClientMemberRepository))
        #expect(!(deps.childRepository is GeneratedClientChildRepository))
    }

    @Test("real mode without a client: every member call throws clientUnavailable")
    func failedMemberRepositoryThrows() async throws {
        let repo = try makeSUT(mode: .real, withClient: false).dependencies.memberRepository

        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.addMember(listId: "list-a", AddMemberInput(email: "friend@example.com", role: .member))
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            try await repo.removeMember(listId: "list-a", userId: "user-a")
        }
    }

    @Test("real mode without a client: every child call throws clientUnavailable")
    func failedChildRepositoryThrows() async throws {
        let repo = try makeSUT(mode: .real, withClient: false).dependencies.childRepository

        await #expect(throws: ConfigurationError.clientUnavailable) { _ = try await repo.fetchChildren() }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await repo.createChild(
                CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .parent)
            )
        }
        await #expect(throws: ConfigurationError.clientUnavailable) { try await repo.deleteChild(id: "child-a") }
    }
}
