//
//  RecordPurchaseViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (f): text-scan evidence over the NEW or REWRITTEN Record Purchase files:
//   - views: Features/Purchases/Views and Components files named RecordPurchase* or BudgetWarning*
//     (the legacy PurchaseRow, PurchaseEditView, PurchaseHistoryView, PurchaseDetailView were
//     deleted in I4b and are not in this set), which must include RecordPurchaseView.swift and the file that declares BudgetWarningPanel;
//   - view state: RecordPurchaseModel, PurchaseRefreshPlan, RecordPurchaseErrorPresentation and
//     RecordPurchaseItemSummary;
//   - Features/Items/Views/ItemDetailView.swift.
//
//  Rules: no legacy GiftItem or purchase type names; no `.alert(`; exactly one `.confirmationDialog(`
//  in the purchase views and it sits on the Record button; no token reference in any view file; no
//  Double arithmetic on money; no raw colors, fonts or spacing; no Log call or interpolated
//  accessibility identifier; no Combine or GCD; no force unwraps; "View Purchase History" and
//  legacyPurchaseItem gone from ItemDetailView.
//
//  Each rule is first proven on synthetic strings (it fires on a violation and stays quiet on the
//  allowed look-alikes), then run over the real files. The existence checks make the real-file
//  tests non-vacuous: a missing file is a failure, never a pass over an empty set.
//
//  Fails today because the view files are not rewritten and the new view-state files do not exist.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase view scan Tests")
struct RecordPurchaseViewScanTests {

    private typealias Rules = RecordPurchaseViewRules

    private func bare(_ source: String) -> String { Rules.bare(ItemSourceScan.codeOnly(source)) }
    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: - Scanner proof: the string and comment blanking

    @Test("bare() blanks string contents, keeps newlines and drops comments")
    func bareBlanksStrings() {
        let result = bare("Text(\"Done! GiftItem\") // GiftItem\nlet a = 1")
        #expect(!result.contains("GiftItem"))
        #expect(!result.contains("Done"))
        #expect(result.contains("Text(\"\")"))
        #expect(result.contains("let a = 1"))
        #expect(bare("let a = \"x\\\"y!\"\nlet b = 2").contains("let b = 2"))
    }

    // MARK: - Scanner proof: each rule fires and stays quiet

    @Test("The legacy name rule fires on the legacy types and not on look-alikes or user-visible text", arguments: [
        ("let item: GiftItem", true), ("var p: Purchase", true), ("let s: ShippingStatus", true),
        ("let w: PurchaseWarning", true), ("let x = item.legacyPurchaseItem", true),
        ("sheet = PurchaseHistoryView()", true), ("let r: PurchaseResponse", true),
        ("let item: ListItem", false), ("let e: PurchaseError", false), ("let d: PurchaseDraft", false),
        ("let p: RecordedPurchase", false), ("let s: ListItemPurchaseSummary", false),
        ("Text(\"Record Purchase\")", false), ("let r: PurchaseRowState", false)
    ])
    func legacyNameRule(source: String, fires: Bool) {
        #expect(Rules.legacyNameViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The alert rule fires on .alert( and not on alert words", arguments: [
        ("Form { }.alert(\"Error\", isPresented: $s) { }", true),
        ("let alertCount = 1", false), ("Text(\"alert\")", false), ("// .alert(\"x\")", false)
    ])
    func alertRule(source: String, fires: Bool) {
        #expect(Rules.alertViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The token rule fires on any token identifier, in any case, and not in a comment or a string", arguments: [
        ("model.confirmationToken", true), ("let token = x", true), ("let pendingToken = x", true),
        ("// the token is secret", false), ("Text(\"token\")", false), ("let tokens = 1", true),
        ("let stoke = 1", false), ("Text(\"a\").foregroundStyle(marker.tokenColor)", false), ("let T = ConfirmationToken()", true)
    ])
    func tokenRule(source: String, fires: Bool) {
        #expect(Rules.tokenViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The floating point rule fires on Double, doubleValue, Float and String(format:)", arguments: [
        ("let x = Double(amount)", true), ("let y = d.doubleValue", true), ("let z: Float = 1", true),
        ("Text(String(format: \"%.2f\", v))", true), ("let a: Decimal = 1", false), ("let doubled = 2", false)
    ])
    func doubleRule(source: String, fires: Bool) {
        #expect(Rules.doubleViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The Combine and GCD rule fires on imports and APIs", arguments: [
        ("import " + "Combine", true), ("Dispatch" + "Queue.main.async { }", true), ("final class M: ObservableObject { }", true),
        ("@Published var a = 1", true), ("try await Task.sleep(nanoseconds: 5)", true),
        ("try await Task.sleep(for: delay)", false), ("// import " + "Combine", false), ("import SwiftUI", false)
    ])
    func combineRule(source: String, fires: Bool) {
        #expect(Rules.combineAndDispatchViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The force unwrap rule fires on postfix ! and not on not, != or text", arguments: [
        ("let a = b!", true), ("let a = f()!", true), ("let a = xs[0]!", true), ("let a = try! f()", true),
        ("let a = b as! C", true), ("if !flag { }", false), ("if a != b { }", false),
        ("Text(\"Done!\")", false), ("let a = b ?? c", false), ("guard !items.isEmpty else { return }", false)
    ])
    func forceUnwrapRule(source: String, fires: Bool) {
        #expect(Rules.forceUnwrapViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The log and identifier rule fires on any Log call, print and interpolated identifiers", arguments: [
        ("LogError(\"x\", category: .business)", true), ("print(\"x\")", true),
        ("Text(\"a\").accessibilityIdentifier(\"row-\\(item.id)\")", true),
        ("Text(\"a\").accessibilityIdentifier(\"recordButton\")", false),
        ("let blogPost = 1", false), ("// LogError(\"x\")", false)
    ])
    func logRule(source: String, fires: Bool) {
        #expect(Rules.logAndIdentifierViolations(inCode: code(source)).isEmpty == !fires, "\(source)")
    }

    @Test("The raw style rule fires on raw colors, system fonts and numeric spacing", arguments: [
        ("Text(\"a\").foregroundStyle(Color.red)", true), ("Text(\"a\").foregroundStyle(.blue)", true),
        ("let c = Color(red: 1, green: 0, blue: 0)", true), ("Text(\"a\").font(.system(size: 12))", true),
        ("Text(\"a\").font(.body)", true), ("VStack(spacing: 8) { }", true), ("Text(\"a\").padding(12)", true),
        ("Text(\"a\").padding(.horizontal, 16)", true), ("RoundedRectangle(cornerRadius: 8)", true),
        ("Text(\"a\").foregroundStyle(Color.textPrimaryColor)", false), ("Text(\"a\").font(.appBody)", false),
        ("VStack(spacing: AppSpacing.sm) { }", false), ("Text(\"a\").padding(AppSpacing.md)", false),
        ("Text(\"a\").padding(.horizontal, AppSpacing.md)", false), ("VStack(spacing: 0) { }", false),
        ("Text(\"a\").redacted(reason: .placeholder)", false), ("Text(\"a\").tint(Color.destructiveColor)", false)
    ])
    func rawStyleRule(source: String, fires: Bool) {
        #expect(Rules.rawStyleViolations(inBare: bare(source)).isEmpty == !fires, "\(source)")
    }

    // MARK: - Scanner proof: confirmationDialog placement

    private let goodRecordButton = """
    Section {
        Button {
            Task { await model.recordTapped() }
        } label: {
            Text("Record")
        }
        .disabled(!model.canTapRecord)
        .confirmationDialog(
            prompt.title,
            isPresented: $model.isShowingOverPurchasePrompt,
            titleVisibility: .visible
        ) {
            Button("Continue Anyway") { Task { await model.confirmOverPurchase() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(prompt.message)
        }
    }
    """

    @Test("The dialog rule finds a dialog attached to a Button and counts it once")
    func dialogOnButtonFound() {
        let text = bare(goodRecordButton)
        #expect(Rules.confirmationDialogCount(inBare: text) == 1)
        let buttons = Rules.buttonsCarryingDialog(inBare: text)
        #expect(buttons.count == 1)
        #expect(buttons.first?.contains("recordTapped") == true)
        #expect(buttons.first?.contains("isShowingOverPurchasePrompt") == true)
        #expect(buttons.first?.contains("role: .cancel") == true)
        #expect(ItemUIRules.confirmationDialogsOnContainers(in: text).isEmpty)
    }

    @Test("The dialog rule does not credit a dialog attached to a Form, a Section or a List")
    func dialogOnContainerNotCredited() {
        let onForm = bare("Form {\n Button(\"Record\") { }\n}\n.confirmationDialog(\"T\", isPresented: $s) { }")
        #expect(Rules.confirmationDialogCount(inBare: onForm) == 1)
        #expect(Rules.buttonsCarryingDialog(inBare: onForm).isEmpty)
        #expect(!ItemUIRules.confirmationDialogsOnContainers(in: onForm).isEmpty)

        let onSection = bare("Section {\n Button(\"Record\") { }\n}\n.confirmationDialog(\"T\", isPresented: $s) { }")
        #expect(Rules.buttonsCarryingDialog(inBare: onSection).isEmpty)

        let onList = bare("List {\n Button(\"Record\") { }\n}\n.confirmationDialog(\"T\", isPresented: $s) { }")
        #expect(Rules.buttonsCarryingDialog(inBare: onList).isEmpty)
        #expect(!ItemUIRules.confirmationDialogsOnContainers(in: onList).isEmpty)
    }

    @Test("The dialog rule counts two dialogs as two")
    func twoDialogsCounted() {
        let text = bare(goodRecordButton + "\n" + goodRecordButton)
        #expect(Rules.confirmationDialogCount(inBare: text) == 2)
        #expect(Rules.buttonsCarryingDialog(inBare: text).count == 2)
    }

    @Test("A dialog mentioned only in a comment is not counted")
    func dialogInCommentIgnored() {
        #expect(Rules.confirmationDialogCount(inBare: bare("// .confirmationDialog(\"x\", isPresented: $s) { }\nText(\"a\")")) == 0)
    }

    // MARK: - Real sources

    private struct SourceFile {
        let path: String
        let raw: String
        let code: String
        let bare: String
    }

    private func load(_ relative: String, tree: ItemSourceTree) throws -> SourceFile? {
        guard tree.exists(relative) else { return nil }
        let raw = try String(contentsOf: tree.file(relative), encoding: .utf8)
        let code = ItemSourceScan.codeOnly(raw)
        return SourceFile(path: relative, raw: raw, code: code, bare: Rules.bare(code))
    }

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    /// Views and components of the new screen: RecordPurchase* and BudgetWarning* in Views or Components.
    private func viewFiles(file: String = #filePath) throws -> [SourceFile] {
        let tree = try tree(file: file)
        var result: [SourceFile] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            let name = url.lastPathComponent
            let inViews = relative.hasPrefix("Features/Purchases/Views/") || relative.hasPrefix("Features/Purchases/Components/")
            guard inViews, name.hasPrefix("RecordPurchase") || name.hasPrefix("BudgetWarning") else { continue }
            if let source = try load(relative, tree: tree) { result.append(source) }
        }
        return result
    }

    private static let viewStateFiles = [
        "Features/Purchases/ViewState/RecordPurchaseModel.swift",
        "Features/Purchases/ViewState/PurchaseRefreshPlan.swift",
        "Features/Purchases/ViewState/RecordPurchaseErrorPresentation.swift",
        "Features/Purchases/ViewState/RecordPurchaseItemSummary.swift"
    ]

    private func viewStateSources(file: String = #filePath) throws -> [SourceFile] {
        let tree = try tree(file: file)
        return try Self.viewStateFiles.compactMap { try load($0, tree: tree) }
    }

    private func itemDetail(file: String = #filePath) throws -> SourceFile {
        let tree = try tree(file: file)
        return try #require(try load("Features/Items/Views/ItemDetailView.swift", tree: tree), "ItemDetailView.swift is missing")
    }

    private func describe(_ found: [(String, [String])]) -> String {
        found.map { "\($0.0): \($0.1.joined(separator: ", "))" }.joined(separator: "\n")
    }

    // MARK: Existence (makes every real-file rule non-vacuous)

    @Test("The new files exist: the view, the panel, the model, the plan, the presentation and the summary")
    func newFilesExist() throws {
        let tree = try tree()
        var missing = Self.viewStateFiles.filter { !tree.exists($0) }
        if !tree.exists("Features/Purchases/Views/RecordPurchaseView.swift") {
            missing.append("Features/Purchases/Views/RecordPurchaseView.swift")
        }
        #expect(missing.isEmpty, "Missing: \(missing)")

        let views = try viewFiles()
        #expect(views.contains { $0.path.hasSuffix("/RecordPurchaseView.swift") })
        #expect(views.contains { $0.bare.contains("struct BudgetWarningPanel") },
                "no file named BudgetWarning* or RecordPurchase* declares struct BudgetWarningPanel")
    }

    @Test("RecordPurchaseView takes a ListItem and the list context, reports through onFinish and is driven by the model")
    func viewShape() throws {
        let views = try viewFiles()
        let view = try #require(views.first { $0.path.hasSuffix("/RecordPurchaseView.swift") }, "RecordPurchaseView.swift is missing")
        for needle in ["ListItem", "ItemListContext", "onFinish", "RecordPurchaseModel", "BudgetWarningPanel", "InlineErrorBanner", "expiryDelay"] {
            let usedHere = view.bare.contains(needle) || views.contains { $0.bare.contains(needle) }
            #expect(usedHere, "no new view file mentions \(needle)")
        }
        #expect(view.bare.contains("@State"))
    }

    // MARK: Legacy names

    @Test("No new or rewritten view names a legacy GiftItem, purchase type or the history screen")
    func noLegacyNamesInViews() throws {
        let views = try viewFiles()
        #expect(!views.isEmpty)
        let found = views.map { ($0.path, Rules.legacyNameViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("No new view-state file names a legacy type")
    func noLegacyNamesInViewState() throws {
        let sources = try viewStateSources()
        #expect(sources.count == Self.viewStateFiles.count, "a new view-state file is missing")
        let found = sources.map { ($0.path, Rules.legacyNameViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("ItemDetailView names no legacy type, no GiftItem, no legacyPurchaseItem and no purchase history")
    func noLegacyNamesInItemDetail() throws {
        let detail = try itemDetail()
        #expect(Rules.legacyNameViolations(inBare: detail.bare).isEmpty, "\(Rules.legacyNameViolations(inBare: detail.bare))")
        #expect(!detail.code.contains("legacyPurchaseItem"))
        #expect(!detail.code.contains("purchaseHistory"), "the DetailSheet.purchaseHistory case is removed")
    }

    @Test("ItemDetailView has no View Purchase History button")
    func noPurchaseHistoryButton() throws {
        let detail = try itemDetail()
        #expect(!detail.code.contains("View Purchase History"))
        #expect(!detail.code.contains("Purchase History"))
    }

    @Test("ItemDetailView presents the new RecordPurchaseView from showsPurchaseEntry and runs the refresh plan")
    func itemDetailIntegration() throws {
        let detail = try itemDetail()
        #expect(detail.bare.contains("RecordPurchaseView("))
        #expect(detail.bare.contains("showsPurchaseEntry"))
        #expect(detail.bare.contains("PurchaseRefreshPlan.steps("))
        #expect(detail.bare.contains("currentItemsListId"))
        #expect(detail.bare.contains("onFinish"))
    }

    // MARK: Alerts

    @Test("No .alert( in the new views or in ItemDetailView")
    func noAlerts() throws {
        let views = try viewFiles() + [try itemDetail()]
        let found = views.map { ($0.path, Rules.alertViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    // MARK: confirmationDialog

    @Test("Exactly one confirmationDialog in the new purchase views, and it sits on the Record button")
    func oneDialogOnRecordButton() throws {
        let views = try viewFiles()
        #expect(!views.isEmpty)
        let total = views.reduce(0) { $0 + Rules.confirmationDialogCount(inBare: $1.bare) }
        #expect(total == 1, "found \(total) .confirmationDialog( calls: \(views.map { "\($0.path)=\(Rules.confirmationDialogCount(inBare: $0.bare))" })")

        let buttons = views.flatMap { Rules.buttonsCarryingDialog(inBare: $0.bare) }
        #expect(buttons.count == 1, "the dialog is not attached to a Button")
        let record = buttons.first ?? ""
        #expect(record.contains("recordTapped"), "the dialog's Button must be the Record button (calls recordTapped)")
        #expect(record.contains("isShowingOverPurchasePrompt"), "bound to model.isShowingOverPurchasePrompt")
        #expect(record.contains("confirmOverPurchase"), "Continue Anyway calls confirmOverPurchase")
        #expect(record.contains("role: .cancel"), "Cancel has role .cancel")
    }

    @Test("No confirmationDialog in the new views sits on a List, ScrollView, Form or NavigationStack")
    func noDialogOnContainer() throws {
        let views = try viewFiles() + viewStateSources()
        #expect(!views.isEmpty)
        let found = views.map { ($0.path, ItemUIRules.confirmationDialogsOnContainers(in: $0.bare).map { "line \($0)" }) }
            .filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("The budget warning panel and the model use no dialog and no alert")
    func panelAndModelHaveNoDialog() throws {
        let panel = try #require(try viewFiles().first { $0.bare.contains("struct BudgetWarningPanel") },
                                 "BudgetWarningPanel is missing")
        #expect(Rules.confirmationDialogCount(inBare: panel.bare) == 0)
        #expect(Rules.alertViolations(inBare: panel.bare).isEmpty)
        for source in try viewStateSources() {
            #expect(Rules.confirmationDialogCount(inBare: source.bare) == 0, "\(source.path)")
        }
    }

    // MARK: Token

    @Test("No token reference in any new view file or in ItemDetailView")
    func noTokenInViews() throws {
        let views = try viewFiles() + [try itemDetail()]
        #expect(views.count >= 2)
        let found = views.map { ($0.path, Rules.tokenViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("No Log call, print or interpolated accessibility identifier in the views, the model or ItemDetailView")
    func noLogOrIdentifierInterpolation() throws {
        let all = try viewFiles() + viewStateSources() + [try itemDetail()]
        let found = all.map { ($0.path, Rules.logAndIdentifierViolations(inCode: $0.code)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("No accessibility text in the new views or the model mentions a token")
    func noTokenInAccessibility() throws {
        let all = try viewFiles() + viewStateSources()
        #expect(!all.isEmpty)
        for source in all {
            let hits = PurchaseScan.accessibilityTokenViolations(in: source.code)
            #expect(hits.isEmpty, "\(source.path): \(hits)")
        }
    }

    // MARK: Money, concurrency, safety, design

    @Test("No Double arithmetic on money in the new views, the model or the view state")
    func noDouble() throws {
        let all = try viewFiles() + viewStateSources()
        #expect(!all.isEmpty)
        let found = all.map { ($0.path, Rules.doubleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("No Combine or GCD in the new views, the model or ItemDetailView")
    func noCombineOrGCD() throws {
        let all = try viewFiles() + viewStateSources() + [try itemDetail()]
        let found = all.map { ($0.path, Rules.combineAndDispatchViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("No force unwraps in the new views, the model or ItemDetailView")
    func noForceUnwraps() throws {
        let all = try viewFiles() + viewStateSources() + [try itemDetail()]
        let found = all.map { ($0.path, Rules.forceUnwrapViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("The new views use the DesignSystem tokens: no raw colors, system fonts or numeric spacing")
    func designTokensOnly() throws {
        let views = try viewFiles()
        #expect(!views.isEmpty)
        let found = views.map { ($0.path, Rules.rawStyleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }
        #expect(found.isEmpty, "\(describe(found))")
    }

    @Test("ItemDetailView keeps to the DesignSystem tokens")
    func itemDetailDesignTokens() throws {
        let detail = try itemDetail()
        let found = Rules.rawStyleViolations(inBare: detail.bare)
        #expect(found.isEmpty, "\(found)")
    }
}
