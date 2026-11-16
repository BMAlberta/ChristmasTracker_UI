//
//  PurchaseHistoryCompositionTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC9: composition of the purchase history loader in AppDependencies, the inert loader, the
//  environment key and the wiring in ChristmasTrackerApp.swift.
//
//  - mock mode builds MockPurchaseHistoryRepository; real mode with a client builds
//    GeneratedClientPurchaseHistoryRepository; real mode without a client builds
//    InertPurchaseHistoryLoader (every call throws ConfigurationError.clientUnavailable) and no Mock;
//  - no mock type is constructed outside makeMock (source scan);
//  - the app builds PurchaseHistoryService from `dependencies.purchaseHistoryLoader`, injects
//    `\.purchaseHistoryService` and passes purchaseHistoryService: after budgetService: to
//    makeProductionClearables (11 clearables, index 10).
//
//  Patterns follow BudgetCompositionTests (real factory-built client with a fake transport).
//

import Foundation
import SwiftUI
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Purchase history composition", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseHistoryCompositionTests {

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
        return AppDependencies.resolve(
            mode: mode, generatedClient: client, reporter: RecordingBootstrapReporter()
        ).dependencies
    }

    // MARK: - Identity

    @Test("mock mode builds the mock history repository, not the generated or inert one")
    func mockModeBuildsMock() throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)

        #expect(deps.purchaseHistoryLoader is MockPurchaseHistoryRepository)
        #expect(!(deps.purchaseHistoryLoader is GeneratedClientPurchaseHistoryRepository))
        #expect(!(deps.purchaseHistoryLoader is InertPurchaseHistoryLoader))
    }

    @Test("real mode with a client builds the generated repository and no Mock")
    func realModeBuildsGenerated() throws {
        let deps = try makeDependencies(mode: .real, withClient: true)

        #expect(deps.purchaseHistoryLoader is GeneratedClientPurchaseHistoryRepository)
        #expect(
            !(deps.purchaseHistoryLoader is MockPurchaseHistoryRepository), "the real branch must not build any Mock"
        )
        #expect(!(deps.purchaseHistoryLoader is InertPurchaseHistoryLoader))
    }

    @Test("real mode without a client builds the inert loader, no Mock and no generated repository")
    func failedBuildsInert() throws {
        let deps = try makeDependencies(mode: .real, withClient: false)

        #expect(deps.purchaseHistoryLoader is InertPurchaseHistoryLoader)
        #expect(!(deps.purchaseHistoryLoader is MockPurchaseHistoryRepository))
        #expect(!(deps.purchaseHistoryLoader is GeneratedClientPurchaseHistoryRepository))
    }

    // MARK: - The inert loader

    @Test("the inert loader returns no data: every call throws ConfigurationError.clientUnavailable")
    func inertLoaderThrows() async {
        let loader = InertPurchaseHistoryLoader()

        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await loader.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await loader.loadPage(
                filter: PurchaseHistoryFilter(year: 2026, recipientId: "u", shippingStatus: .shipped), cursor: "c"
            )
        }
    }

    @Test("real mode without a client: a call through the composed dependencies throws")
    func composedInertThrows() async throws {
        let deps = try makeDependencies(mode: .real, withClient: false)

        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await deps.purchaseHistoryLoader.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
    }

    @Test("mock mode: the composed loader returns the seed rows, first page of 20 with a cursor")
    func composedMockReturnsRows() async throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)

        let page = try await deps.purchaseHistoryLoader.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(
            page.rows == Array(
                MockPurchaseHistoryRepository.seedRows.prefix(GeneratedClientPurchaseHistoryRepository.pageLimit)
            )
        )
        #expect(page.nextCursor != nil)
    }

    // MARK: - Environment key

    @Test("the environment has a default PurchaseHistoryService built on the inert loader")
    func environmentDefault() async {
        let environment = EnvironmentValues()
        let service = environment.purchaseHistoryService

        #expect(environment.purchaseHistoryService === service, "the default is one shared instance")
        await #expect(throws: PurchaseHistoryError.server) {
            _ = try await service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
    }

    @Test("the environment value can be replaced")
    func environmentOverride() {
        var environment = EnvironmentValues()
        let custom = PurchaseHistoryService(repository: MockPurchaseHistoryRepository())

        environment.purchaseHistoryService = custom

        #expect(environment.purchaseHistoryService === custom)
    }

    // MARK: - Source scan of the composition root

    private func appSource(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source("ChristmasTrackerApp.swift"), "Could not read ChristmasTrackerApp.swift")
        return ItemSourceScan.codeOnly(raw)
    }

    @Test("the mock history repository is constructed in ChristmasTrackerApp.swift only inside makeMock")
    func mockOnlyInMakeMock() throws {
        let code = try appSource()
        let makeMock = try #require(ItemSourceScan.braceBody(after: "func makeMock", in: code))
        let outside = code.replacingOccurrences(of: makeMock, with: "")

        #expect(makeMock.contains("MockPurchaseHistoryRepository("))
        #expect(!outside.contains("MockPurchaseHistoryRepository("), "the mock is constructed outside makeMock")
    }

    @Test("makeReal builds the generated repository and makeInert builds the inert loader")
    func realAndInertWiring() throws {
        let code = try appSource()
        let makeReal = try #require(ItemSourceScan.braceBody(after: "func makeReal", in: code))
        let makeInert = try #require(ItemSourceScan.braceBody(after: "func makeInert", in: code))

        #expect(makeReal.contains("GeneratedClientPurchaseHistoryRepository(client: generatedClient)"))
        #expect(!makeReal.contains("MockPurchaseHistoryRepository"))
        #expect(makeInert.contains("InertPurchaseHistoryLoader()"))
        #expect(!makeInert.contains("MockPurchaseHistoryRepository"))
    }

    @Test("the three AppDependencies factories set purchaseHistoryLoader")
    func factoriesSetTheLoader() throws {
        let code = try appSource()

        for header in ["func makeMock", "func makeReal", "func makeInert"] {
            let body = try #require(ItemSourceScan.braceBody(after: header, in: code), "\(header) not found")
            #expect(body.contains("purchaseHistoryLoader"), "\(header) must set purchaseHistoryLoader")
        }
    }

    @Test("the app builds the service from the dependencies and injects it into the environment")
    func appWiresTheService() throws {
        let code = try appSource()

        #expect(code.contains("PurchaseHistoryService(") && code.contains("dependencies.purchaseHistoryLoader"))
        #expect(code.contains(".environment(\\.purchaseHistoryService"))
    }

    @Test("makeProductionClearables gets purchaseHistoryService: after budgetService:")
    func appRegistersTheClearable() throws {
        let code = try appSource()
        let flat = code.replacingOccurrences(of: "\n", with: " ")

        let ordered = try ItemSourceScan.matchingLines(
            #"makeProductionClearables\(.*purchaseService:.*statsService:.*budgetService:.*purchaseHistoryService:"#,
            in: flat
        )

        #expect(ordered.isEmpty == false, "purchaseHistoryService: is the final argument, after budgetService:")
    }

    @Test("SessionClearable.swift appends the history service last")
    func clearablesSourceAppendsLast() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let raw = try #require(tree.source("Features/Authentication/Services/SessionClearable.swift"))
        let code = ItemSourceScan.codeOnly(raw)

        #expect(code.contains("purchaseHistoryService: PurchaseHistoryService"))
        let flat = code.replacingOccurrences(of: "\n", with: " ")
        let lastEntry = try ItemSourceScan.matchingLines(#"budgetService,\s*purchaseHistoryService\s*\]"#, in: flat)
        #expect(lastEntry.isEmpty == false, "the list ends with budgetService, purchaseHistoryService")
    }
}
