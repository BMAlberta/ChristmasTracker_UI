//
//  BudgetCompositionTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: composition of the stats loader and the budget manager in AppDependencies, the inert
//  types, and the registration of the two services (Gate 1 Story B, Composition).
//
//  - mock mode builds MockStatsRepository and MockBudgetRepository sharing ONE MockBudgetStore seeded
//    with the current year from the Calendar; real mode with a client builds the two generated-client
//    repositories; real mode without a client builds InertStatsLoader and InertBudgetManager (every
//    call throws BudgetError.server) and no Mock;
//  - no mock type is constructed outside makeMock (source scan);
//  - the app builds StatsService and BudgetService from those dependencies, injects `\.statsService`,
//    `\.budgetService` and `\.spendingCacheInvalidator`, and appends statsService: then budgetService:
//    after purchaseService: in makeProductionClearables (10 clearables, indices 8 and 9);
//  - the two purchase screens pass the environment invalidator to the refresh runner.
//
//  Patterns follow PurchaseManagementCompositionTests (real factory-built client with a fake transport).
//

import Foundation
import SwiftUI
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Budget composition Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetCompositionTests {

    // MARK: - Factory

    private func makeDependencies(mode: APIMode, withClient: Bool) throws -> AppDependencies {
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
        return AppDependencies.resolve(mode: mode, generatedClient: client, reporter: RecordingBootstrapReporter()).dependencies
    }

    // MARK: - Identity

    @Test("mock mode builds the Mock stats and budget repositories, not the generated or inert ones")
    func mockModeBuildsMocks() throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)

        #expect(deps.statsLoader is MockStatsRepository)
        #expect(deps.budgetManager is MockBudgetRepository)
        #expect(!(deps.statsLoader is GeneratedClientStatsRepository))
        #expect(!(deps.budgetManager is GeneratedClientBudgetRepository))
        #expect(!(deps.statsLoader is InertStatsLoader))
        #expect(!(deps.budgetManager is InertBudgetManager))
    }

    @Test("real mode with a client builds the generated repositories and no Mock")
    func realModeBuildsGenerated() throws {
        let deps = try makeDependencies(mode: .real, withClient: true)

        #expect(deps.statsLoader is GeneratedClientStatsRepository)
        #expect(deps.budgetManager is GeneratedClientBudgetRepository)
        #expect(!(deps.statsLoader is MockStatsRepository), "the real branch must not build any Mock")
        #expect(!(deps.budgetManager is MockBudgetRepository), "the real branch must not build any Mock")
        #expect(!(deps.statsLoader is InertStatsLoader))
        #expect(!(deps.budgetManager is InertBudgetManager))
    }

    @Test("real mode without a client builds the inert types, no Mock and no generated repository")
    func failedBuildsInertTypes() throws {
        let deps = try makeDependencies(mode: .real, withClient: false)

        #expect(deps.statsLoader is InertStatsLoader)
        #expect(deps.budgetManager is InertBudgetManager)
        #expect(!(deps.statsLoader is MockStatsRepository))
        #expect(!(deps.budgetManager is MockBudgetRepository))
        #expect(!(deps.statsLoader is GeneratedClientStatsRepository))
        #expect(!(deps.budgetManager is GeneratedClientBudgetRepository))
    }

    // MARK: - The inert types

    @Test("the inert stats loader returns no data: every call throws BudgetError.server")
    func inertStatsLoaderThrows() async {
        let loader = InertStatsLoader()

        await #expect(throws: BudgetError.server) { _ = try await loader.yearStats(year: 2026) }
    }

    @Test("the inert budget manager returns no data: every call throws BudgetError.server")
    func inertBudgetManagerThrows() async {
        let manager = InertBudgetManager()

        await #expect(throws: BudgetError.server) { _ = try await manager.listBudgets() }
        await #expect(throws: BudgetError.server) { _ = try await manager.budget(year: 2026) }
        await #expect(throws: BudgetError.server) { _ = try await manager.create(BudgetServiceFix.createRequest()) }
        await #expect(throws: BudgetError.server) { _ = try await manager.update(BudgetServiceFix.updateRequest()) }
        await #expect(throws: BudgetError.server) { try await manager.delete(year: 2026) }
        await #expect(throws: BudgetError.server) { _ = try await manager.duplicate(BudgetServiceFix.duplicateRequest()) }
    }

    @Test("real mode without a client: every call through the composed dependencies throws")
    func composedInertThrows() async throws {
        let deps = try makeDependencies(mode: .real, withClient: false)

        await #expect(throws: BudgetError.server) { _ = try await deps.statsLoader.yearStats(year: 2026) }
        await #expect(throws: BudgetError.server) { _ = try await deps.budgetManager.listBudgets() }
    }

    // MARK: - Mock mode shares one store

    @Test("mock mode is seeded with the current year from the Calendar")
    func mockSeedIsTheCurrentYear() async throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)
        let currentYear = Calendar.current.component(.year, from: Date())

        let budgets = try await deps.budgetManager.listBudgets()

        #expect(budgets.map(\.year) == [currentYear])
        let stats = try await deps.statsLoader.yearStats(year: currentYear)
        #expect(stats.budget != nil)
    }

    @Test("mock mode: a budget created through the composed manager shows in the composed stats loader")
    func mockStoreIsShared() async throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)
        let nextYear = Calendar.current.component(.year, from: Date()) + 1

        let created = try await deps.budgetManager.create(
            CreateBudgetRequest(year: nextYear, totalBudget: BudgetFixtures.dec("300"), recipients: [])
        )
        let stats = try await deps.statsLoader.yearStats(year: nextYear)

        #expect(created.year == nextYear)
        #expect(stats.budget?.totalBudget == BudgetFixtures.dec("300"))
    }

    @Test("mock mode: a year the mock never created is notFound")
    func mockUnknownYear() async throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)

        await #expect(throws: BudgetError.notFound) { _ = try await deps.budgetManager.budget(year: 1999) }
    }

    @Test("two mock-mode resolutions do not share state")
    func mockStoresAreIndependent() async throws {
        let one = try makeDependencies(mode: .mock, withClient: false)
        let two = try makeDependencies(mode: .mock, withClient: false)
        let nextYear = Calendar.current.component(.year, from: Date()) + 1

        _ = try await one.budgetManager.create(
            CreateBudgetRequest(year: nextYear, totalBudget: BudgetFixtures.dec("300"), recipients: [])
        )

        await #expect(throws: BudgetError.notFound) { _ = try await two.budgetManager.budget(year: nextYear) }
    }

    // MARK: - Source scan of the composition root

    private func appSource(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source("ChristmasTrackerApp.swift"), "Could not read ChristmasTrackerApp.swift")
        return ItemSourceScan.codeOnly(raw)
    }

    @Test("the budget mocks and the mock store are constructed in ChristmasTrackerApp.swift only inside makeMock")
    func mocksOnlyInMakeMock() throws {
        let code = try appSource()
        let makeMock = try #require(ItemSourceScan.braceBody(after: "func makeMock", in: code))
        let outside = code.replacingOccurrences(of: makeMock, with: "")

        for type in ["MockBudgetStore(", "MockStatsRepository(", "MockBudgetRepository("] {
            #expect(makeMock.contains(type), "makeMock builds \(type)")
            #expect(!outside.contains(type), "\(type) is constructed outside makeMock")
        }
    }

    @Test("makeReal builds the generated repositories and makeInert builds the inert types")
    func realAndInertWiring() throws {
        let code = try appSource()
        let makeReal = try #require(ItemSourceScan.braceBody(after: "func makeReal", in: code))
        let makeInert = try #require(ItemSourceScan.braceBody(after: "func makeInert", in: code))

        #expect(makeReal.contains("GeneratedClientStatsRepository(client: generatedClient)"))
        #expect(makeReal.contains("GeneratedClientBudgetRepository(client: generatedClient)"))
        for mock in ["MockStatsRepository", "MockBudgetRepository", "MockBudgetStore"] {
            #expect(!makeReal.contains(mock))
            #expect(!makeInert.contains(mock))
        }
        #expect(makeInert.contains("InertStatsLoader()"))
        #expect(makeInert.contains("InertBudgetManager()"))
    }

    @Test("the mock store is built from the current year read from a Calendar in makeMock")
    func mockStoreIsSeededFromTheCalendar() throws {
        let code = try appSource()
        let makeMock = try #require(ItemSourceScan.braceBody(after: "func makeMock", in: code))

        #expect(makeMock.contains("MockBudgetStore(currentYear:"))
        #expect(makeMock.contains("Calendar"))
    }

    @Test("the app builds both services from the dependencies and injects them with the invalidator")
    func appWiresTheServices() throws {
        let code = try appSource()

        #expect(code.contains("StatsService(") && code.contains("dependencies.statsLoader"))
        #expect(code.contains("BudgetService(") && code.contains("dependencies.budgetManager"))
        #expect(code.contains("SpendingCacheInvalidator("))
        #expect(code.contains(".environment(\\.statsService"))
        #expect(code.contains(".environment(\\.budgetService"))
        #expect(code.contains(".environment(\\.spendingCacheInvalidator"))
    }

    @Test("makeProductionClearables gets statsService: then budgetService: after purchaseService:")
    func appRegistersTheClearablesInOrder() throws {
        let code = try appSource()
        let flat = code.replacingOccurrences(of: "\n", with: " ")

        let ordered = try ItemSourceScan.matchingLines(
            #"makeProductionClearables\(.*purchaseService:.*statsService:.*budgetService:"#, in: flat
        )

        #expect(ordered.isEmpty == false, "statsService: and budgetService: follow purchaseService: in that order")
    }

    // MARK: - The two runner construction sites

    @Test("ItemDetailView and ManagePurchaseView build the runner with the environment invalidator")
    func runnerSitesPassTheInvalidator() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        var sites = 0
        for url in tree.all where ["ItemDetailView.swift", "ManagePurchaseView.swift"].contains(url.lastPathComponent) {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            sites += 1
            #expect(code.contains("PurchaseRefreshRunner("), "\(url.lastPathComponent) builds the runner")
            #expect(code.contains("spendingCacheInvalidator"), "\(url.lastPathComponent) reads the environment value")
            #expect(code.contains("spendingCaches:"), "\(url.lastPathComponent) hands it to the runner")
        }
        #expect(sites == 2, "both construction sites exist")
    }
}
