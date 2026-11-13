//
//  DeleteRefreshMoveScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-C: text-scan evidence that the delete's follow-up refresh moved from the host view to the
//  model (so it no longer depends on the screen staying visible).
//
//   - ItemDetailView.handlePurchaseDetailFinish: `.deleted` only closes the pushed screen (no plan, no
//     run); `.gone` keeps closing AND runs PurchaseRefreshPlan.steps through the runner;
//   - PurchaseDetailModel names the delete plan and the session check, and reads the generation
//     BEFORE it calls the delete;
//   - ManagePurchaseView builds the refresh dependency from the environment services and the runner;
//   - PurchaseRefreshRunner has the guarded run; PurchaseService exposes the read-only generation;
//   - no GCD, no Combine, no force unwrap in the touched files.
//
//  The existing scans (ManagePurchaseViewScanTests: one confirmationDialog on the Delete button,
//  destructive role and tint, design tokens, no log call) keep running unchanged.
//
//  These scans pin the moved refresh: the host, model, view, runner and service names listed above.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Delete refresh move scan Tests")
struct DeleteRefreshMoveScanTests {

    private typealias Rules = RecordPurchaseViewRules
    private typealias Scan = PurchaseScreenScan

    private static let hostPath = "Features/Items/Views/ItemDetailView.swift"
    private static let modelPath = "Features/Purchases/ViewState/PurchaseDetailModel.swift"
    private static let viewPath = "Features/Purchases/Views/ManagePurchaseView.swift"
    private static let runnerPath = "Features/Purchases/ViewState/PurchaseRefreshRunner.swift"
    private static let servicePath = "Features/Purchases/Services/PurchaseService.swift"

    private func source(_ path: String, file: String = #filePath) throws -> ScreenSource {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        return try #require(Scan.load(path, tree: tree), "\(path) is missing")
    }

    /// The text of one `case` of the finish switch: from `marker` to the next `case ` (or the end).
    private func caseSegment(_ marker: String, in body: String) -> String? {
        guard let start = body.range(of: marker) else { return nil }
        let rest = body[start.upperBound...]
        if let next = rest.range(of: "case .") {
            return String(rest[..<next.lowerBound])
        }
        return String(rest)
    }

    // MARK: Host

    @Test("The host's .deleted case only closes the pushed screen: no plan and no run")
    func hostDeletedOnlyCloses() throws {
        let host = try source(Self.hostPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func handlePurchaseDetailFinish", in: host.bare),
                                "handlePurchaseDetailFinish is missing")
        let deleted = try #require(caseSegment("case .deleted", in: body), "the .deleted case is missing")
        #expect(!deleted.contains("PurchaseRefreshPlan"))
        #expect(!deleted.contains("stepsAfterDelete"))
        #expect(!deleted.contains(".run("))
        #expect(!body.contains("stepsAfterDelete"), "the host no longer builds the delete plan")
        #expect(body.contains("openedPurchase = nil"), "the pushed screen is still closed")
    }

    @Test("The host's .gone case still closes the screen and runs PurchaseRefreshPlan.steps through the runner")
    func hostGoneKeepsPlan() throws {
        let host = try source(Self.hostPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func handlePurchaseDetailFinish", in: host.bare),
                                "handlePurchaseDetailFinish is missing")
        #expect(body.contains("case .gone"))
        #expect(body.contains("PurchaseRefreshPlan.steps("))
        #expect(body.contains("refreshRunner.run("))
        #expect(body.contains("openedPurchase = nil"))
    }

    @Test("The item views no longer name stepsAfterDelete anywhere")
    func itemViewsDoNotNameDeletePlan() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let views = Scan.allFiles(in: "Features/Items/Views/", tree: tree)
        #expect(!views.isEmpty)
        for view in views {
            #expect(!view.bare.contains("stepsAfterDelete"), "\(view.path) still builds the delete plan")
        }
    }

    // MARK: Model

    @Test("The model runs the delete plan through a refresh dependency, guarded by the service session and cancellation")
    func modelRunsGuardedPlan() throws {
        let model = try source(Self.modelPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func confirmDelete", in: model.bare), "confirmDelete is missing")
        #expect(body.contains("stepsAfterDelete("))
        #expect(model.bare.contains("sessionGeneration"))
        #expect(model.bare.contains("isCancelled"))
        #expect(model.bare.contains("currentItemsListId"))
    }

    @Test("confirmDelete reads the session generation BEFORE it calls the delete")
    func generationCapturedBeforeDelete() throws {
        let model = try source(Self.modelPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func confirmDelete", in: model.bare), "confirmDelete is missing")
        let generation = try #require(body.range(of: "sessionGeneration"), "confirmDelete never reads the generation")
        let delete = try #require(body.range(of: "service.deletePurchase"), "confirmDelete never deletes")
        #expect(generation.lowerBound < delete.lowerBound)
    }

    @Test("The model sets finish before it starts the refresh and never touches finish or banners from the refresh")
    func finishBeforeRefresh() throws {
        let model = try source(Self.modelPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func confirmDelete", in: model.bare), "confirmDelete is missing")
        let plan = try #require(body.range(of: "stepsAfterDelete("), "the plan is not built in confirmDelete")
        #expect(model.bare.contains("finish = .deleted"), "finish = .deleted is missing")
        // finish = .deleted lives in finishDeleted() (called from confirmDelete) or in the body itself.
        let calledFirst = body.range(of: "finishDeleted()").map { $0.lowerBound < plan.lowerBound } ?? false
        let inBodyFirst = body.range(of: "finish = .deleted").map { $0.lowerBound < plan.lowerBound } ?? false
        #expect(calledFirst || inBodyFirst, "finish must be set before the refresh starts")
    }

    @Test("The model has no GCD, Combine or force unwrap")
    func modelHygiene() throws {
        let model = try source(Self.modelPath)
        #expect(Rules.combineAndDispatchViolations(inBare: model.bare).isEmpty)
        #expect(Rules.forceUnwrapViolations(inBare: model.bare).isEmpty)
        #expect(Rules.combineAndDispatchViolations(inBare: model.bare).isEmpty)
    }

    // MARK: View

    @Test("ManagePurchaseView builds the refresh dependency from the item service, the list service and the runner")
    func viewBuildsDependency() throws {
        let view = try source(Self.viewPath)
        #expect(view.bare.contains("itemService"))
        #expect(view.bare.contains("listService"))
        #expect(view.bare.contains("PurchaseRefreshRunner("))
        #expect(view.bare.contains("refresh"))
        #expect(!view.bare.contains("stepsAfterDelete"), "the plan is built by the model, not the view")
        #expect(Rules.combineAndDispatchViolations(inBare: view.bare).isEmpty)
    }

    // MARK: Runner and service

    @Test("The runner has the guarded run and the unguarded run")
    func runnerHasGuardedRun() throws {
        let runner = try source(Self.runnerPath)
        #expect(runner.bare.contains("func run(_ steps: [PurchaseRefreshStep], while"))
        #expect(runner.bare.contains("func run(_ steps: [PurchaseRefreshStep])"))
        #expect(runner.bare.contains("shouldContinue"))
        #expect(Rules.combineAndDispatchViolations(inBare: runner.bare).isEmpty)
        #expect(Rules.forceUnwrapViolations(inBare: runner.bare).isEmpty)
    }

    @Test("PurchaseService exposes the generation read-only and keeps the stored one private")
    func serviceAccessor() throws {
        let service = try source(Self.servicePath)
        #expect(service.bare.contains("var sessionGeneration: Int"))
        #expect(service.bare.contains("private var generation"))
        #expect(Rules.combineAndDispatchViolations(inBare: service.bare).isEmpty)
    }
}
