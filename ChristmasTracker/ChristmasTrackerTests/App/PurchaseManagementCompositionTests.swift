//
//  PurchaseManagementCompositionTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: composition of the purchase manager in AppDependencies and the inert manager
//  (Gate 1 Story B interface items 5 and 7).
//
//  - mock mode builds MockPurchaseManager sharing its store with the mock recorder, real mode with a
//    client builds GeneratedClientPurchaseManagementRepository, real mode without a client builds
//    InertPurchaseManager and no Mock;
//  - the mock manager is constructed only inside makeMock (source scan);
//  - the inert manager returns no data: every call throws (the equivalent of the inert recorder);
//  - the PurchaseService is built from BOTH the recorder and the manager;
//  - the environment default still works.
//
//  Patterns follow PurchaseCompositionTests (real factory-built client with a fake transport).
//

import Foundation
import SwiftUI
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Purchase management composition Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseManagementCompositionTests {

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

    @Test("mock mode builds the Mock purchase manager, not the generated or inert one")
    func mockModeBuildsMockManager() throws {
        let manager = try makeDependencies(mode: .mock, withClient: false).purchaseManager

        #expect(manager is MockPurchaseManager)
        #expect(!(manager is GeneratedClientPurchaseManagementRepository))
        #expect(!(manager is InertPurchaseManager))
    }

    @Test("real mode with a client builds the generated management repository and no Mock")
    func realModeBuildsGeneratedManager() throws {
        let manager = try makeDependencies(mode: .real, withClient: true).purchaseManager

        #expect(manager is GeneratedClientPurchaseManagementRepository)
        #expect(!(manager is MockPurchaseManager), "the real branch must not build any Mock purchase manager")
        #expect(!(manager is InertPurchaseManager))
    }

    @Test("real mode without a client builds the inert manager, no Mock and no generated repository")
    func failedBuildsInertManager() throws {
        let manager = try makeDependencies(mode: .real, withClient: false).purchaseManager

        #expect(manager is InertPurchaseManager)
        #expect(!(manager is MockPurchaseManager))
        #expect(!(manager is GeneratedClientPurchaseManagementRepository))
    }

    // MARK: - The inert manager

    @Test("the inert manager returns no data: every call throws", arguments: ManagementOp.allCases)
    func inertManagerThrows(op: ManagementOp) async {
        let manager = InertPurchaseManager()

        do {
            _ = try await op.call(manager)
            Issue.record("the inert manager must not return a purchase (\(op))")
        } catch let error as PurchaseManagementError {
            #expect(error == .server, "the typed equivalent of the inert recorder's failure")
        } catch let error as ConfigurationError {
            #expect(error == .clientUnavailable, "the same failure the inert recorder throws")
        } catch {
            Issue.record("unexpected error from the inert manager: \(error)")
        }
    }

    @Test("real mode without a client: every management call through the composed manager throws",
          arguments: ManagementOp.allCases)
    func composedInertManagerThrows(op: ManagementOp) async throws {
        let manager = try makeDependencies(mode: .real, withClient: false).purchaseManager

        await #expect(throws: (any Error).self) {
            _ = try await op.call(manager)
        }
    }

    // MARK: - Mock mode shares one store

    @Test("mock mode: a purchase recorded through the composed recorder can be opened through the composed manager")
    func mockStoreIsShared() async throws {
        let deps = try makeDependencies(mode: .mock, withClient: false)
        let outcome = try await deps.purchaseRecorder.createPurchase(
            itemId: "mock-item-child-3", draft: PurchaseFixtures.draft(quantity: 1, totalCost: "5"), confirmationToken: nil
        )
        guard case .created(let created) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }

        let fetched = try await deps.purchaseManager.fetchPurchase(id: created.id)
        let updated = try await deps.purchaseManager.updateNotes(
            id: created.id, update: PurchaseNotesUpdate(change: .set("Gift wrap please"))
        )
        let deleted = try await deps.purchaseManager.deletePurchase(id: created.id)

        #expect(fetched == created)
        #expect(updated.notes == "Gift wrap please")
        #expect(deleted.id == created.id)
        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await deps.purchaseManager.fetchPurchase(id: created.id)
        }
    }

    @Test("mock mode: an id the mock never recorded is notFound")
    func mockUnknownId() async throws {
        let manager = try makeDependencies(mode: .mock, withClient: false).purchaseManager

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await manager.fetchPurchase(id: "purchase-not-in-the-mock")
        }
    }

    // The mock item data shows purchase summary rows. Every summary whose purchaser is the mock
    // signed-in user must be openable through the composed manager (the store is seeded from the
    // item data); a summary of anyone else must not be. With the current seed no summary belongs to
    // the signed-in user, so the first half has nothing to check until the seed gains one.
    @Test("mock mode: the signed-in user's summary rows can be opened and other users' rows cannot")
    func mockSeedMatchesTheItemData() async throws {
        let manager = try makeDependencies(mode: .mock, withClient: false).purchaseManager
        let me = MockItemRepository.defaultUser
        let summaries = MockItemSeed.items.flatMap { $0.purchases ?? [] }

        for summary in summaries {
            if summary.purchaser.id == me.id {
                let purchase = try await manager.fetchPurchase(id: summary.id)
                #expect(purchase.id == summary.id)
                #expect(purchase.purchaser.id == me.id)
                #expect(purchase.quantity == summary.quantity)
                #expect(purchase.totalCost == summary.totalCost)
            } else {
                await #expect(throws: PurchaseManagementError.notFound) {
                    _ = try await manager.fetchPurchase(id: summary.id)
                }
            }
        }
    }

    // MARK: - Environment key

    @Test("the environment still has a default PurchaseService that is idle")
    func environmentDefaultStillWorks() {
        let environment = EnvironmentValues()
        let service = environment.purchaseService

        #expect(service.isMutating == false)
        #expect(environment.purchaseService === service)
    }

    @Test("the environment value can still be replaced by a service built with a manager")
    func environmentOverrideWithManager() async {
        var environment = EnvironmentValues()
        let custom = PurchaseService(
            repository: MockPurchaseRecorder(access: { _ in .unknown }),
            management: InertPurchaseManager()
        )

        environment.purchaseService = custom

        #expect(environment.purchaseService === custom)
    }

    // MARK: - Source scan of the composition root

    private func appSource(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source("ChristmasTrackerApp.swift"), "Could not read ChristmasTrackerApp.swift")
        return ItemSourceScan.codeOnly(raw)
    }

    @Test("MockPurchaseManager and MockPurchaseStore are constructed in ChristmasTrackerApp.swift only inside makeMock")
    func mockManagerOnlyInMakeMock() throws {
        let code = try appSource()
        let makeMock = try #require(ItemSourceScan.braceBody(after: "func makeMock", in: code))
        let outside = code.replacingOccurrences(of: makeMock, with: "")

        #expect(makeMock.contains("MockPurchaseManager("))
        #expect(makeMock.contains("MockPurchaseStore("))
        #expect(!outside.contains("MockPurchaseManager("), "the mock manager is constructed outside makeMock")
        #expect(!outside.contains("MockPurchaseStore("), "the mock store is constructed outside makeMock")
    }

    @Test("makeReal builds the generated management repository and makeInert builds the inert manager")
    func realAndInertWiring() throws {
        let code = try appSource()
        let makeReal = try #require(ItemSourceScan.braceBody(after: "func makeReal", in: code))
        let makeInert = try #require(ItemSourceScan.braceBody(after: "func makeInert", in: code))

        #expect(makeReal.contains("GeneratedClientPurchaseManagementRepository(client: generatedClient)"))
        #expect(!makeReal.contains("MockPurchaseManager"))
        #expect(!makeReal.contains("MockPurchaseStore"))
        #expect(makeInert.contains("InertPurchaseManager()"))
        #expect(!makeInert.contains("MockPurchaseManager"))
        #expect(!makeInert.contains("MockPurchaseStore"))
    }

    @Test("the app builds the PurchaseService from the recorder AND the manager")
    func appWiresTheServiceWithTheManager() throws {
        let code = try appSource()

        #expect(code.contains("dependencies.purchaseRecorder"))
        #expect(code.contains("dependencies.purchaseManager"))
        #expect(code.contains("management:"), "PurchaseService(repository:management:) is used")
    }
}
