//
//  ManagePurchaseViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: text-scan evidence over the NEW purchase detail files:
//   - views: every file under Features/Purchases/Views whose name starts with ManagePurchase (this
//     must include ManagePurchaseView.swift);
//   - view state: Features/Purchases/ViewState/PurchaseDetailModel.swift.
//
//  Rules (UI RULES FOR NEW CODE, Story C test list): the one confirmationDialog is attached to the
//  Delete button (never to a List, ScrollView, Form, NavigationStack or screen container); every
//  destructive button carries role .destructive and Color.destructiveColor; no raw color, font or
//  spacing literals; no .alert(; no Log call, print or accessibility identifier interpolation; no
//  Combine or GCD; no force unwraps; no Double on money; no legacy type names; the notes save never
//  names a tracking number; the model never reads PurchaseService.isMutating.
//
//  The rule functions are the existing, already proven RecordPurchaseViewRules and ItemUIRules. A
//  missing file is a failed expectation, never a pass over an empty set.
//
//  Fails today because the screen and its model do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Manage purchase view scan Tests")
struct ManagePurchaseViewScanTests {

    private typealias Rules = RecordPurchaseViewRules
    private typealias Scan = PurchaseScreenScan

    private static let viewPath = "Features/Purchases/Views/ManagePurchaseView.swift"
    private static let modelPath = "Features/Purchases/ViewState/PurchaseDetailModel.swift"

    // MARK: Loading

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func views(file: String = #filePath) throws -> [ScreenSource] {
        Scan.files(in: "Features/Purchases/Views/", prefix: "ManagePurchase", tree: try tree(file: file))
    }

    private func model(file: String = #filePath) throws -> ScreenSource? {
        Scan.load(Self.modelPath, tree: try tree(file: file))
    }

    private func mainView(file: String = #filePath) throws -> ScreenSource {
        try #require(try views(file: file).first { $0.path == Self.viewPath }, "ManagePurchaseView.swift is missing")
    }

    // MARK: Scanner proof: the properties checked on the Delete button

    private let goodDeleteButton = """
    Section {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Text("Delete")
        }
        .foregroundStyle(Color.destructiveColor)
        .confirmationDialog(
            PurchaseDetailState.deleteTitle,
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(PurchaseDetailState.deleteButtonTitle, role: .destructive) { Task { await model.confirmDelete() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(PurchaseDetailState.deleteMessage)
        }
    }
    """

    @Test("Proof: a Delete button with its dialog is found once, with the destructive role twice and the tint")
    func scannerProofGoodButton() {
        let text = Rules.bare(ItemSourceScan.codeOnly(goodDeleteButton))
        let buttons = Rules.buttonsCarryingDialog(inBare: text)
        #expect(Rules.confirmationDialogCount(inBare: text) == 1)
        #expect(buttons.count == 1)
        let delete = buttons.first ?? ""
        #expect(Scan.occurrences(of: "role: .destructive", in: delete) == 2)
        #expect(delete.contains("Color.destructiveColor"))
        #expect(delete.contains("confirmDelete"))
        #expect(ItemUIRules.confirmationDialogsOnContainers(in: text).isEmpty)
    }

    @Test("Proof: a dialog on a List is not credited to a Button")
    func scannerProofBadContainer() {
        let text = Rules.bare(ItemSourceScan.codeOnly(
            "List {\n Button(role: .destructive) { }\n}\n.confirmationDialog(\"T\", isPresented: $s) { }"
        ))
        #expect(Rules.buttonsCarryingDialog(inBare: text).isEmpty)
        #expect(!ItemUIRules.confirmationDialogsOnContainers(in: text).isEmpty)
    }

    // MARK: Existence

    @Test("The new files exist: ManagePurchaseView and PurchaseDetailModel")
    func filesExist() throws {
        let tree = try tree()
        var missing: [String] = []
        for path in [Self.viewPath, Self.modelPath] where !tree.exists(path) { missing.append(path) }
        #expect(missing.isEmpty, "Missing: \(missing)")
    }

    @Test("The view is a SwiftUI View driven by the model, and the model is a MainActor Observable class")
    func typeShapes() throws {
        let view = try mainView()
        #expect(view.bare.contains("struct ManagePurchaseView"))
        #expect(view.bare.contains(": View"))
        #expect(view.bare.contains("PurchaseDetailModel"))

        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        #expect(source.bare.contains("class PurchaseDetailModel"))
        #expect(source.bare.contains("@Observable"))
        #expect(source.bare.contains("@MainActor"))
        #expect(source.bare.contains("PurchaseDetailFinish"))
    }

    // MARK: The delete confirmation

    @Test("Exactly one confirmationDialog in the new views, attached to the Delete button")
    func oneDialogOnDeleteButton() throws {
        let all = try views()
        #expect(!all.isEmpty)
        let total = all.reduce(0) { $0 + Rules.confirmationDialogCount(inBare: $1.bare) }
        #expect(total == 1, "found \(total) .confirmationDialog( calls: \(all.map { "\($0.path)=\(Rules.confirmationDialogCount(inBare: $0.bare))" })")

        let buttons = all.flatMap { Rules.buttonsCarryingDialog(inBare: $0.bare) }
        #expect(buttons.count == 1, "the dialog is not attached to a Button")
        let delete = buttons.first ?? ""
        #expect(delete.contains("confirmDelete"), "the destructive button calls confirmDelete")
        #expect(delete.contains("PurchaseDetailState.deleteTitle"))
        #expect(delete.contains("PurchaseDetailState.deleteMessage"))
        #expect(delete.contains("PurchaseDetailState.deleteButtonTitle"))
        #expect(delete.contains("role: .cancel"), "the dialog has a Cancel")
    }

    @Test("Every destructive button carries role .destructive and Color.destructiveColor")
    func destructiveRoleAndTint() throws {
        let all = try views()
        #expect(!all.isEmpty)
        let delete = all.flatMap { Rules.buttonsCarryingDialog(inBare: $0.bare) }.first ?? ""
        #expect(Scan.occurrences(of: "role: .destructive", in: delete) >= 2,
                "the Delete button and the dialog's destructive button both use role: .destructive")
        #expect(delete.contains("Color.destructiveColor"), "the Delete button is tinted with Color.destructiveColor")
        let anywhere = all.reduce(0) { $0 + Scan.occurrences(of: "Color.destructiveColor", in: $1.bare) }
        #expect(anywhere >= 1)
    }

    @Test("No confirmationDialog sits on a List, ScrollView, Form or NavigationStack")
    func noDialogOnContainer() throws {
        let all = try views()
        #expect(!all.isEmpty)
        let found = all.map { ($0.path, ItemUIRules.confirmationDialogsOnContainers(in: $0.bare).map { "line \($0)" }) }
            .filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("The model has no dialog and no alert")
    func modelHasNoDialog() throws {
        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        #expect(Rules.confirmationDialogCount(inBare: source.bare) == 0)
        #expect(Rules.alertViolations(inBare: source.bare).isEmpty)
    }

    @Test("No .alert( in the new views (errors use InlineErrorBanner)")
    func noAlerts() throws {
        let all = try views()
        #expect(!all.isEmpty)
        let found = all.map { ($0.path, Rules.alertViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    // MARK: Content

    @Test("The view shows the immutable sentence, the two sections with their own banners and the load banner")
    func viewContent() throws {
        let view = try mainView()
        for needle in [
            "PurchaseDetailState.immutableSentence", "Picker", "TextField", "InlineErrorBanner",
            "loadBanner", "shippingBanner", "notesBanner", "deleteBanner",
            "saveShipping", "saveNotes", "confirmDelete", "remainingCharacters"
        ] {
            #expect(view.bare.contains(needle), "ManagePurchaseView does not mention \(needle)")
        }
        #expect(view.code.contains("axis: .vertical"), "the notes field is a vertical-axis TextField")
    }

    @Test("The view announces results through AccessibilityNotification.Announcement and keeps 44-point targets")
    func accessibility() throws {
        let view = try mainView()
        #expect(view.bare.contains("AccessibilityNotification.Announcement"))
        #expect(view.bare.contains("announcement"))
        #expect(view.bare.contains("minimumButtonHeight"))
        #expect(view.bare.contains("accessibilityLabel") || view.bare.contains("accessibilityHint"))
    }

    @Test("The new views have light and dark previews")
    func previews() throws {
        let all = try views()
        let combined = all.map(\.bare).joined(separator: "\n")
        #expect(Scan.occurrences(of: "#Preview", in: combined) >= 2, "at least a light and a dark preview")
        #expect(combined.contains(".dark"))
    }

    @Test("The view loads on appear and clears the transient errors on disappear")
    func lifecycle() throws {
        let view = try mainView()
        #expect(view.bare.contains(".task"))
        #expect(view.bare.contains("disappear()"))
    }

    // MARK: Model rules

    @Test("The model decides ownership with PurchasePermissions and calls the four service methods")
    func modelUsesTheService() throws {
        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        for needle in [
            "PurchasePermissions.canManage", "service.fetchPurchase", "service.updateShipping",
            "service.updateNotes", "service.deletePurchase"
        ] {
            #expect(source.bare.contains(needle), "PurchaseDetailModel does not mention \(needle)")
        }
    }

    @Test("The model never reads PurchaseService.isMutating")
    func modelIgnoresIsMutating() throws {
        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        #expect(!source.bare.contains("isMutating"))
    }

    @Test("The notes save never names a tracking number")
    func notesSaveHasNoTracking() throws {
        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        let body = try #require(ItemSourceScan.braceBody(after: "func saveNotes", in: source.bare), "saveNotes is missing")
        #expect(!body.lowercased().contains("tracking"))
        #expect(!body.contains("updateShipping"))
    }

    @Test("The model decides ownership from the purchaser id and never from a role")
    func modelNeverReadsRoles() throws {
        let source = try #require(try model(), "PurchaseDetailModel.swift is missing")
        #expect(!source.bare.contains("myRole"))
        #expect(!source.bare.contains("ListRole"))
    }

    // MARK: Legacy names

    @Test("No new file names a legacy purchase type, the legacy detail or the history screen")
    func noLegacyNames() throws {
        let all = try views() + [try model()].compactMap { $0 }
        #expect(all.count >= 2, "the view and the model must exist")
        let found = all.map { source -> (String, [String]) in
            var hits = Rules.legacyNameViolations(inBare: source.bare)
            if source.bare.range(of: #"\b(PurchaseDetailView|PurchaseEditView|PurchaseRow)\b"#, options: .regularExpression) != nil {
                hits.append("legacy view name")
            }
            return (source.path, hits)
        }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    // MARK: Safety and design

    @Test("No Log call, print or interpolated accessibility identifier in the views or the model")
    func noLogOrIdentifierInterpolation() throws {
        let all = try views() + [try model()].compactMap { $0 }
        #expect(all.count >= 2, "the view and the model must exist")
        let found = all.map { ($0.path, Rules.logAndIdentifierViolations(inCode: $0.code)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("No Combine, GCD or force unwrap in the views or the model")
    func noCombineGCDOrForceUnwrap() throws {
        let all = try views() + [try model()].compactMap { $0 }
        #expect(all.count >= 2, "the view and the model must exist")
        let found = all.map { ($0.path, Rules.combineAndDispatchViolations(inBare: $0.bare) + Rules.forceUnwrapViolations(inBare: $0.bare)) }
            .filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("No Double arithmetic on money in the views or the model")
    func noDouble() throws {
        let all = try views() + [try model()].compactMap { $0 }
        #expect(all.count >= 2, "the view and the model must exist")
        let found = all.map { ($0.path, Rules.doubleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("The new views use the DesignSystem tokens: no raw colors, system fonts or numeric spacing")
    func designTokensOnly() throws {
        let all = try views()
        #expect(!all.isEmpty)
        let found = all.map { ($0.path, Rules.rawStyleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(Scan.describe(found))")
        let combined = all.map(\.bare).joined(separator: "\n")
        #expect(combined.contains("AppSpacing."), "spacing comes from AppSpacing")
    }
}
