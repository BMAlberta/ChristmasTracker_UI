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
}
