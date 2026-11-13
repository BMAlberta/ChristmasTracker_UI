//
//  ItemDetailPurchaseOpenScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: text-scan evidence for the item detail integration of the purchase detail:
//   - an openable purchase row (PurchaseRowState.canOpen) is a Button with a trailing chevron and the
//     row's accessibility hint; a row that is not openable stays the plain row (no Button, no action);
//   - tapping an openable row presents ManagePurchaseView with the row's purchase id and the item's
//     id and list id, and the signed-in user's id for the ownership defense;
//   - the host runs the refresh through PurchaseRefreshRunner for recorded, check item and delete,
//     and dismisses the pushed screen on .deleted and .gone;
//   - the view never decides ownership itself (no role, no purchaser id comparison).
//
//  The view-state truth tables for the rows (every persona, active and archived lists) live in
//  ItemPurchaseRowStateTests. The earlier scans (RecordPurchaseViewScanTests, ItemUIRulesScanTests)
//  keep running over ItemDetailView and are not relaxed.
//
//  Fails today because ItemDetailView does not open the purchase detail yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Item detail purchase open scan Tests")
struct ItemDetailPurchaseOpenScanTests {

    private typealias Rules = RecordPurchaseViewRules
    private typealias Scan = PurchaseScreenScan

    private static let detailPath = "Features/Items/Views/ItemDetailView.swift"

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func detail(file: String = #filePath) throws -> ScreenSource {
        try #require(Scan.load(Self.detailPath, tree: try tree(file: file)), "ItemDetailView.swift is missing")
    }

    /// ItemDetailView plus any other file in Features/Items/Views (the purchase card may be its own file).
    private func itemViews(file: String = #filePath) throws -> [ScreenSource] {
        Scan.allFiles(in: "Features/Items/Views/", tree: try tree(file: file))
    }

    @Test("ItemDetailView presents ManagePurchaseView with the purchase, item and list ids and the current user")
    func presentsManagePurchaseView() throws {
        let views = try itemViews()
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("ManagePurchaseView("))
        #expect(combined.contains("purchaseId"))
        #expect(combined.contains("itemId"))
        #expect(combined.contains("listId"))
        #expect(combined.contains("currentUserId"))
        let usesNavigation = combined.contains("navigationDestination") || combined.contains("NavigationLink")
        #expect(usesNavigation, "the purchase detail is a navigation push from the item detail")
    }

    @Test("An openable row is a Button with a chevron and the row's accessibility hint")
    func openableRow() throws {
        let views = try itemViews()
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("canOpen"), "the row branches on PurchaseRowState.canOpen")
        #expect(combined.contains("chevron"), "an openable row shows a trailing chevron")
        #expect(combined.contains("accessibilityHint"), "the hint comes from PurchaseRowState.accessibilityHint")
    }

    @Test("The row hint text is not duplicated in the view (it comes from the row state)")
    func hintComesFromState() throws {
        let views = try itemViews()
        for view in views {
            #expect(!view.code.contains("Opens your purchase"), "\(view.path) hard-codes the hint")
        }
    }

    @Test("The view does not decide ownership: no purchaser id comparison and no role")
    func viewDoesNotDecideOwnership() throws {
        let detail = try detail()
        let comparison = detail.bare.range(of: #"purchaser\.id\s*(==|!=)"#, options: .regularExpression)
        #expect(comparison == nil, "ownership is decided only by PurchasePermissions.canManage")
        #expect(!detail.bare.contains("PurchasePermissions"), "the view reads PurchaseRowState.canOpen instead")
    }

    @Test("ItemDetailView runs the refresh through PurchaseRefreshRunner and no longer switches over the steps")
    func usesRefreshRunner() throws {
        let detail = try detail()
        #expect(detail.bare.contains("PurchaseRefreshRunner("))
        #expect(detail.bare.contains(".run("))
        #expect(!detail.bare.contains("case .itemsLoad"), "the step switch moved into the runner")
        #expect(!detail.bare.contains("case .itemsRefresh"), "the step switch moved into the runner")
    }

    @Test("ItemDetailView handles .checkItem like .recorded: it closes the sheet and force-refreshes")
    func handlesCheckItem() throws {
        let detail = try detail()
        #expect(detail.bare.contains("case .checkItem"))
        #expect(detail.bare.contains("PurchaseRefreshPlan.steps("), "check item uses the same plan as recorded")
        #expect(detail.bare.contains("case .recorded"))
        #expect(detail.bare.contains("case .itemGone"))
    }

    @Test("ItemDetailView dismisses the pushed screen on .deleted and .gone; the delete plan now runs in the model (I4c-C)")
    func handlesDeleted() throws {
        let views = try itemViews()
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(!combined.contains("PurchaseRefreshPlan.stepsAfterDelete("), "the model runs the delete refresh, once")
        #expect(combined.contains(".deleted"))
        #expect(combined.contains(".gone"))
        #expect(combined.contains("PurchaseDetailFinish"))
    }

    @Test("ItemDetailView keeps leaving the screen when the item is reported gone")
    func keepsGoneItemHandling() throws {
        let detail = try detail()
        #expect(detail.bare.contains("goneItemId"))
        #expect(detail.bare.contains("dismiss()"))
    }

    @Test("The item views carry no Combine, GCD, force unwrap, log call or alert after the change")
    func hygiene() throws {
        let detail = try detail()
        #expect(Rules.combineAndDispatchViolations(inBare: detail.bare).isEmpty)
        #expect(Rules.forceUnwrapViolations(inBare: detail.bare).isEmpty)
        #expect(Rules.logAndIdentifierViolations(inCode: detail.code).isEmpty)
        #expect(Rules.alertViolations(inBare: detail.bare).isEmpty)
        #expect(Rules.rawStyleViolations(inBare: detail.bare).isEmpty, "\(Rules.rawStyleViolations(inBare: detail.bare))")
    }
}
