//
//  PurchaseCompositionTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: composition of the purchase recorder in AppDependencies.
//
//  - mock mode builds MockPurchaseRecorder (access derived from the mock seed items and
//    MockListRepository.capabilities), real mode with a client builds
//    GeneratedClientPurchaseRepository, real mode without a client builds InertPurchaseRecorder
//    (every call throws ConfigurationError.clientUnavailable) and no Mock;
//  - MockPurchaseRecorder is constructed only inside makeMock (source scan, in addition to
//    BootstrapSourceScanTests);
//  - the app injects the PurchaseService through the environment, and the environment key has a
//    default service built on a mock recorder.
//
//  Patterns follow AppDependenciesResolveTests (real factory-built client with a fake transport).
//

import Foundation
import SwiftUI
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Purchase composition Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseCompositionTests {

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

    private func draft(_ amount: String = "10") -> PurchaseDraft {
        PurchaseFixtures.draft(quantity: 1, totalCost: amount)
    }

    // MARK: - Identity

    @Test("mock mode builds the Mock purchase recorder, not the generated or inert one")
    func mockModeBuildsMockRecorder() throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        #expect(recorder is MockPurchaseRecorder)
        #expect(!(recorder is GeneratedClientPurchaseRepository))
        #expect(!(recorder is InertPurchaseRecorder))
    }

    @Test("real mode with a client builds the generated purchase repository and no Mock")
    func realModeBuildsGeneratedRepository() throws {
        let recorder = try makeDependencies(mode: .real, withClient: true).purchaseRecorder

        #expect(recorder is GeneratedClientPurchaseRepository)
        #expect(!(recorder is MockPurchaseRecorder), "the real branch must not build any Mock purchase recorder")
        #expect(!(recorder is InertPurchaseRecorder))
    }

    @Test("real mode without a client builds the inert recorder, no Mock and no generated repository")
    func failedBuildsInertRecorder() throws {
        let recorder = try makeDependencies(mode: .real, withClient: false).purchaseRecorder

        #expect(recorder is InertPurchaseRecorder)
        #expect(!(recorder is MockPurchaseRecorder))
        #expect(!(recorder is GeneratedClientPurchaseRepository))
    }

    @Test("real mode without a client: createPurchase throws clientUnavailable, with or without a token")
    func inertRecorderThrows() async throws {
        let recorder = try makeDependencies(mode: .real, withClient: false).purchaseRecorder

        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await recorder.createPurchase(itemId: "item-a", draft: draft(), confirmationToken: nil)
        }
        await #expect(throws: ConfigurationError.clientUnavailable) {
            _ = try await recorder.createPurchase(itemId: "item-a", draft: draft(), confirmationToken: PurchaseWire.token)
        }
    }

    // MARK: - Mock mode follows the mock lists

    @Test("mock mode: a purchase on an item of a list the user may buy from is recorded")
    func mockModeAllowsPurchasableLists() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        for itemId in ["mock-item-child-3", "mock-item-member-1", "mock-item-archived-2"] {
            let outcome = try await recorder.createPurchase(itemId: itemId, draft: draft("5"), confirmationToken: nil)
            guard case .created(let purchase) = outcome else {
                Issue.record("expected .created for \(itemId), got \(outcome)")
                continue
            }
            #expect(purchase.itemId == itemId)
            #expect(purchase.recipient.id.isEmpty == false)
        }
    }

    @Test("mock mode: an item of the user's own (blind) list is refused with cannotPurchaseOwnList")
    func mockModeOwnList() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        await #expect(throws: PurchaseError.cannotPurchaseOwnList) {
            _ = try await recorder.createPurchase(itemId: "mock-item-self-2", draft: draft(), confirmationToken: nil)
        }
    }

    @Test("mock mode: viewer-role and PUBLIC non-member lists are refused with forbidden")
    func mockModeViewerAndPublic() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        for itemId in ["mock-item-viewer-2", "mock-item-public-1"] {
            await #expect(throws: PurchaseError.forbidden) {
                _ = try await recorder.createPurchase(itemId: itemId, draft: draft(), confirmationToken: nil)
            }
        }
    }

    @Test("mock mode: a blind co-owner's list is refused (own list or forbidden), never recorded")
    func mockModeBlindCoOwner() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        let thrown = await capturePurchaseError {
            _ = try await recorder.createPurchase(itemId: "mock-item-coowner-1", draft: draft(), confirmationToken: nil)
        }

        #expect(thrown == .cannotPurchaseOwnList || thrown == .forbidden, "got \(String(describing: thrown))")
    }

    @Test("mock mode: an item the mock does not know is notFound (never forbidden)")
    func mockModeUnknownItem() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder

        await #expect(throws: PurchaseError.notFound) {
            _ = try await recorder.createPurchase(itemId: "item-not-in-the-mock", draft: draft(), confirmationToken: nil)
        }
    }

    @Test("mock mode: the budget flow works end to end through the composed recorder")
    func mockModeBudgetFlow() async throws {
        let recorder = try makeDependencies(mode: .mock, withClient: false).purchaseRecorder
        let overBudget = draft("75")

        let first = try await recorder.createPurchase(itemId: "mock-item-child-3", draft: overBudget, confirmationToken: nil)

        guard case .confirmationRequired(_, let token) = first else {
            Issue.record("expected .confirmationRequired, got \(first)")
            return
        }
        let second = try await recorder.createPurchase(itemId: "mock-item-child-3", draft: overBudget, confirmationToken: token)
        guard case .created = second else {
            Issue.record("expected .created on the resubmit, got \(second)")
            return
        }
    }

    // MARK: - Environment key

    @Test("the environment has a default PurchaseService built on a mock recorder")
    func environmentDefault() async {
        let environment = EnvironmentValues()
        let service = environment.purchaseService

        #expect(service.isMutating == false)
        #expect(environment.purchaseService === service, "the default is one shared instance")
    }

    @Test("the environment value can be replaced")
    func environmentOverride() {
        var environment = EnvironmentValues()
        let custom = PurchaseService(repository: MockPurchaseRecorder(access: { _ in .unknown }))

        environment.purchaseService = custom

        #expect(environment.purchaseService === custom)
    }

    // MARK: - Source scan of the composition root

    private func appSource(file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source("ChristmasTrackerApp.swift"), "Could not read ChristmasTrackerApp.swift")
        return ItemSourceScan.codeOnly(raw)
    }

    @Test("MockPurchaseRecorder is constructed in ChristmasTrackerApp.swift only inside makeMock")
    func recorderOnlyInMakeMock() throws {
        let code = try appSource()
        let makeMock = try #require(ItemSourceScan.braceBody(after: "func makeMock", in: code))
        let outside = code.replacingOccurrences(of: makeMock, with: "")

        #expect(makeMock.contains("MockPurchaseRecorder("))
        #expect(!outside.contains("MockPurchaseRecorder("), "the mock recorder is constructed outside makeMock")
    }

    @Test("makeReal builds the generated repository and makeInert builds the inert recorder")
    func realAndInertWiring() throws {
        let code = try appSource()
        let makeReal = try #require(ItemSourceScan.braceBody(after: "func makeReal", in: code))
        let makeInert = try #require(ItemSourceScan.braceBody(after: "func makeInert", in: code))

        #expect(makeReal.contains("GeneratedClientPurchaseRepository(client: generatedClient)"))
        #expect(!makeReal.contains("MockPurchaseRecorder"))
        #expect(makeInert.contains("InertPurchaseRecorder()"))
        #expect(!makeInert.contains("MockPurchaseRecorder"))
    }

    @Test("the app builds the PurchaseService from the recorder, registers it last and injects it")
    func appWiresTheService() throws {
        let code = try appSource()

        #expect(code.contains("PurchaseService(") && code.contains("dependencies.purchaseRecorder"))
        let passesIt = try ItemSourceScan.matchingLines(#"makeProductionClearables\([^)]*purchaseService:"#, in: code.replacingOccurrences(of: "\n", with: " "))
        #expect(passesIt.isEmpty == false, "makeProductionClearables gets the new final parameter")
        #expect(code.contains(".environment(\\.purchaseService"))
    }
}
