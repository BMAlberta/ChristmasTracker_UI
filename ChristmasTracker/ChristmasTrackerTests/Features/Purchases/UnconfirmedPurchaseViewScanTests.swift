//
//  UnconfirmedPurchaseViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: text-scan evidence for the unconfirmed-purchase UI wiring:
//   - InlineErrorBanner gains optional onCheckItem and onRecordAgain closures (default nil) and its
//     action switch handles the two new actions without a default case;
//   - RecordPurchaseView wires the banner's Check Item and Record Again to the model;
//   - the model and presentation files stay free of the rules the earlier scans enforce.
//
//  The earlier RecordPurchaseViewScanTests keep running over the same files (one dialog on the
//  Record button, no token reference, no raw styles, no log calls); nothing here relaxes them.
//
//  Fails today because the banner and the Record Purchase view are not yet wired.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Unconfirmed purchase view scan Tests")
struct UnconfirmedPurchaseViewScanTests {

    private typealias Rules = RecordPurchaseViewRules
    private typealias Scan = PurchaseScreenScan

    private static let bannerPath = "DesignSystem/Components/InlineErrorBanner.swift"
    private static let recordViewPath = "Features/Purchases/Views/RecordPurchaseView.swift"
    private static let modelPath = "Features/Purchases/ViewState/RecordPurchaseModel.swift"

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func source(_ path: String, file: String = #filePath) throws -> ScreenSource {
        try #require(Scan.load(path, tree: try tree(file: file)), "\(path) is missing")
    }

    /// The Record Purchase view files: every RecordPurchase* file under Views (the wiring may sit in a subview).
    private func recordViews(file: String = #filePath) throws -> [ScreenSource] {
        Scan.files(in: "Features/Purchases/Views/", prefix: "RecordPurchase", tree: try tree(file: file))
    }

    // MARK: InlineErrorBanner

    @Test("InlineErrorBanner has optional onCheckItem and onRecordAgain closures defaulting to nil")
    func bannerClosures() throws {
        let banner = try source(Self.bannerPath)
        for name in ["onCheckItem", "onRecordAgain"] {
            #expect(banner.bare.contains(name), "InlineErrorBanner does not declare \(name)")
            let pattern = name + #"\s*:\s*\(\(\)\s*->\s*Void\)\?\s*=\s*nil"#
            #expect(banner.bare.range(of: pattern, options: .regularExpression) != nil,
                    "\(name) must be an optional closure with a nil default in the initializer")
        }
        #expect(banner.bare.contains("onTryAgain") && banner.bare.contains("onDismiss"), "the existing closures stay")
    }

    @Test("The banner's action switch handles the new actions and has no default case")
    func bannerSwitch() throws {
        let banner = try source(Self.bannerPath)
        let body = try #require(ItemSourceScan.braceBody(after: "func perform", in: banner.bare), "perform is missing")
        #expect(body.contains("case .checkItem"))
        #expect(body.contains("case .recordAgain"))
        #expect(body.contains("case .tryAgain"))
        #expect(body.contains("case .dismiss"))
        #expect(!body.contains("default:"))
        #expect(body.contains("onCheckItem?()"))
        #expect(body.contains("onRecordAgain?()"))
    }

    @Test("The banner keeps the 44-point button height and the DesignSystem tokens")
    func bannerKeepsRules() throws {
        let banner = try source(Self.bannerPath)
        #expect(banner.bare.contains("minimumButtonHeight"))
        #expect(Rules.rawStyleViolations(inBare: banner.bare).isEmpty, "\(Rules.rawStyleViolations(inBare: banner.bare))")
        #expect(Rules.combineAndDispatchViolations(inBare: banner.bare).isEmpty)
        #expect(Rules.logAndIdentifierViolations(inCode: banner.code).isEmpty)
        #expect(Rules.alertViolations(inBare: banner.bare).isEmpty)
    }

    // MARK: RecordPurchaseView

    @Test("The Record Purchase view wires Check Item to checkItem() and Record Again to recordAgain()")
    func recordViewWiring() throws {
        let views = try recordViews()
        #expect(views.contains { $0.path == Self.recordViewPath }, "RecordPurchaseView.swift is missing")
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("onCheckItem"))
        #expect(combined.contains("onRecordAgain"))
        #expect(combined.contains("checkItem()"))
        #expect(combined.contains("recordAgain()"))
    }

    @Test("Record Again runs in a Task (it is async) and nothing in the view retries automatically")
    func recordViewNothingAutomatic() throws {
        let views = try recordViews()
        #expect(!views.isEmpty)
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("await model.recordAgain()") || combined.contains("await recordAgain()"))
        // No retry is triggered from a lifecycle hook or a state change.
        let automatic = (try? ItemSourceScan.matchingLines(#"\.(onChange|onAppear)\([^\n]*(retry|recordAgain)"#, in: combined)) ?? [-1]
        #expect(automatic.isEmpty, "found an automatic retry at \(automatic)")
    }

    @Test("The Record Purchase view still shows the Try Again path for definitive failures")
    func recordViewKeepsTryAgain() throws {
        let views = try recordViews()
        let combined = views.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("onTryAgain"))
        #expect(combined.contains("retry()"))
    }

    // MARK: Model

    @Test("The Record Purchase model declares checkItem() and recordAgain() and the .checkItem finish")
    func modelShape() throws {
        let model = try source(Self.modelPath)
        #expect(model.bare.contains("func checkItem()"))
        #expect(model.bare.contains("func recordAgain() async"))
        #expect(model.bare.contains("case checkItem"))
    }

    @Test("The model still logs nothing and uses no Combine, GCD or force unwrap")
    func modelRules() throws {
        let model = try source(Self.modelPath)
        #expect(Rules.logAndIdentifierViolations(inCode: model.code).isEmpty)
        #expect(Rules.combineAndDispatchViolations(inBare: model.bare).isEmpty)
        #expect(Rules.forceUnwrapViolations(inBare: model.bare).isEmpty)
    }
}
