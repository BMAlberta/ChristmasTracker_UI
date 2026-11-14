//
//  BudgetViewScanRuleTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: scanner self-proof. Every rule of BudgetViewRules is shown to fire on a bad synthetic
//  sample and to allow a good one before it is trusted on the real files (BudgetViewScanTests).
//
//  The sample lists are typed static lets built from short literals (no long concatenations in @Test
//  arguments). The words of the forbidden concurrency APIs are built from pieces.
//

import Foundation
import Testing

@Suite("Budget view scan rule Tests")
struct BudgetViewScanRuleTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    private func bare(_ source: String) -> String { RecordPurchaseViewRules.bare(ItemSourceScan.codeOnly(source)) }

    // MARK: Design tokens

    static let badTokenSamples: [String] = [
        #"Text("a").foregroundColor(.primary)"#,
        "Text(\"a\").foregroundStyle(Color.red)",
        "Text(\"a\").foregroundStyle(Color.gray)",
        "Rectangle().fill(Color(red: 1, green: 0, blue: 0))",
        "Rectangle().background(.blue)",
        "Text(\"a\").font(.system(size: 12))",
        "Text(\"a\").font(.headline)",
        "Text(\"a\").padding(16)",
        "Text(\"a\").padding(.horizontal, 12)",
        "VStack(spacing: 8) {",
        "Rectangle().frame(width: 44, height: 44)",
        "Rectangle().frame(minHeight: 44)",
        "Text(\"a\").foregroundColor(Color.destructiveColor)"
    ]

    static let goodTokenSamples: [String] = [
        "Text(\"a\").foregroundStyle(Color.destructiveColor)",
        "Text(\"a\").font(AppTypography.appTitle1)",
        "Text(\"a\").padding(AppSpacing.md)",
        "Text(\"a\").padding(.horizontal, AppSpacing.lg)",
        "VStack(spacing: AppSpacing.sm) {",
        "Button(\"a\") {}.frame(minHeight: InlineErrorBannerState.minimumButtonHeight)",
        "Text(\"a\").frame(maxWidth: .infinity, alignment: .leading)",
        "// Text(\"a\").padding(16)",
        "Text(\"Over by 16 dollars, spacing: 8\")"
    ]

    @Test("the token rules fire on raw colors, system fonts, foregroundColor and numeric layout", arguments: badTokenSamples)
    func tokenRulesFire(source: String) {
        #expect(!BudgetViewRules.tokenViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    @Test("the token rules allow tokens, the minimum button height, comments and words in literals", arguments: goodTokenSamples)
    func tokenRulesAllow(source: String) {
        #expect(BudgetViewRules.tokenViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    // MARK: SwiftUI rules

    static let badSwiftUISamples: [String] = [
        "Text(\"a\").onTapGesture { }",
        "let view = AnyView(Text(\"a\"))",
        "GeometryReader { proxy in Text(\"a\") }",
        "let width = UIScreen.main.bounds.width",
        "ForEach(items.indices, id: \\.self) { index in Text(\"a\") }",
        "Text(\"a\").sheet(isPresented: $show) { Text(\"b\") }"
    ]

    static let goodSwiftUISamples: [String] = [
        "Button(\"a\") { }",
        "ForEach(rows) { row in Text(row.name) }",
        "Text(\"a\").sheet(item: $model.presentedSheet) { sheet in Text(\"b\") }",
        "// GeometryReader is not used"
    ]

    @Test("the SwiftUI rule fires on tap gestures, AnyView, GeometryReader, indices and sheet(isPresented:)",
          arguments: badSwiftUISamples)
    func swiftUIRuleFires(source: String) {
        #expect(!BudgetViewRules.swiftUIRuleViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    @Test("the SwiftUI rule allows buttons, ForEach over rows, sheet(item:) and comments", arguments: goodSwiftUISamples)
    func swiftUIRuleAllows(source: String) {
        #expect(BudgetViewRules.swiftUIRuleViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    // MARK: Identifiers

    static let badIdentifierSamples: [String] = [
        #".accessibilityIdentifier("budget-\(year)")"#,
        #".accessibilityIdentifier("row_\(row.id)")"#,
        #".accessibilityIdentifier("person-\(name)-limit")"#
    ]

    static let goodIdentifierSamples: [String] = [
        #".accessibilityIdentifier("budget-card")"#,
        #".accessibilityLabel("Spent \(spent)")"#,
        #"// .accessibilityIdentifier("budget-\(year)")"#
    ]

    @Test("the identifier rule fires on an interpolated accessibility identifier", arguments: badIdentifierSamples)
    func identifierRuleFires(source: String) {
        #expect(!BudgetViewRules.identifierInterpolationViolations(inCode: code(source)).isEmpty, "\(source)")
    }

    @Test("the identifier rule allows static identifiers, interpolated labels and comments", arguments: goodIdentifierSamples)
    func identifierRuleAllows(source: String) {
        #expect(BudgetViewRules.identifierInterpolationViolations(inCode: code(source)).isEmpty, "\(source)")
    }

    // MARK: Logs and Sentry

    static let badLogSamples: [String] = [
        #"LogInfo("opened")"#,
        #"LogError("failed", category: .business)"#,
        #"print("hello")"#,
        "SentrySDK.capture(error: failure)",
        "import Sentry"
    ]

    static let goodLogSamples: [String] = [
        "let catalog = 1",
        #"// LogInfo("opened")"#,
        #"Text("LogInfo(")"#,
        "let sentryless = 2",
        "let loginView = 3"
    ]

    @Test("the log rule fires on log calls, print and Sentry", arguments: badLogSamples)
    func logRuleFires(source: String) {
        #expect(!BudgetViewRules.logAndSentryViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    @Test("the log rule allows look-alike names, comments and words in literals", arguments: goodLogSamples)
    func logRuleAllows(source: String) {
        #expect(BudgetViewRules.logAndSentryViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    // MARK: Raw errors

    static let badErrorSamples: [String] = [
        #"Text("Failed: \(error)")"#,
        "let text = error.localizedDescription",
        "let text = String(describing: error)",
        #"let text = "x \(error.localizedDescription)""#
    ]

    static let goodErrorSamples: [String] = [
        "if let typed = error as? BudgetError { banner = typed.userMessage }",
        "// String(describing: error) is never used",
        "let errorCount = 1"
    ]

    @Test("the error rule fires on an interpolated, described or localized error", arguments: badErrorSamples)
    func errorRuleFires(source: String) {
        #expect(!BudgetViewRules.errorInterpolationViolations(inCode: code(source)).isEmpty, "\(source)")
    }

    @Test("the error rule allows a typed error, comments and look-alike names", arguments: goodErrorSamples)
    func errorRuleAllows(source: String) {
        #expect(BudgetViewRules.errorInterpolationViolations(inCode: code(source)).isEmpty, "\(source)")
    }

    // MARK: Concurrency

    static let concurrencyCases: [(String, Bool)] = {
        let dispatchPrefix: String = "Dispatch"
        let queueSuffix: String = "Queue"
        let combineWord: String = "Comb" + "ine"
        let observable: String = "Observable" + "Object"
        let published: String = "@" + "Published"
        let queueLine: String = "let q = " + dispatchPrefix + queueSuffix + ".main"
        let importLine: String = "import " + combineWord
        let observableLine: String = "final class Model: " + observable + " {}"
        let publishedLine: String = published + " var total = 0"
        let taskLine: String = "let task = Task { await work() }"
        let observationLine: String = "@Observable final class Model {}"
        return [
            (queueLine, true),
            (importLine, true),
            (observableLine, true),
            (publishedLine, true),
            (taskLine, false),
            (observationLine, false)
        ]
    }()

    @Test("the concurrency rule fires on GCD, Combine and Combine-era observation and allows async and @Observable",
          arguments: concurrencyCases)
    func concurrencyRule(source: String, fires: Bool) {
        #expect(BudgetViewRules.concurrencyViolations(inCode: code(source)).isEmpty == !fires, "\(source)")
    }

    // MARK: Ad-hoc error text

    static let badErrorTextSamples: [String] = [
        "Text(error.localizedDescription)",
        "Text(model.errorMessage)",
        "Text(message)",
        "Text(banner.message)",
        "Text(verbatim: failure.userMessage)",
        "Text(model.loadFailure)"
    ]

    static let goodErrorTextSamples: [String] = [
        "Text(state.emptyMessage)",
        "Text(\"Could not load\")",
        "Text(StatsScreenModel.deleteMessage)",
        "Text(row.statusText)",
        "InlineErrorBanner(state: banner, onDismiss: { })",
        "// Text(error.localizedDescription)"
    ]

    @Test("the ad-hoc error rule fires on a Text that renders an error, a message or a banner", arguments: badErrorTextSamples)
    func adHocErrorRuleFires(source: String) {
        #expect(!BudgetViewRules.adHocErrorTextViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    @Test("the ad-hoc error rule allows other text, the delete message, the banner view and comments",
          arguments: goodErrorTextSamples)
    func adHocErrorRuleAllows(source: String) {
        #expect(BudgetViewRules.adHocErrorTextViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    // MARK: confirmationDialog

    private static let menuWithDialog: String = """
        Menu {
            Button("Edit Budget") { }
        } label: {
            Image(systemName: "ellipsis")
        }
        .confirmationDialog("Delete?", isPresented: $model.isShowingDeleteConfirmation) {
            Button("Delete Budget", role: .destructive) { }
        }
        """

    private static let listWithDialog: String = """
        List {
            Text("a")
        }
        .confirmationDialog("Delete?", isPresented: $model.isShowingDeleteConfirmation) {
            Button("Delete Budget", role: .destructive) { }
        }
        """

    private static let menuWithoutDialog: String = """
        Menu {
            Button("Edit Budget") { }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        """

    private static let dialogOnStack: String = """
        VStack {
            Menu { Button("Edit Budget") { } } label: { Image(systemName: "ellipsis") }
        }
        .confirmationDialog("Delete?", isPresented: $model.isShowingDeleteConfirmation) {
            Button("Delete Budget", role: .destructive) { }
        }
        """

    @Test("the dialog count is one for a menu with a dialog and zero without")
    func dialogCount() {
        #expect(BudgetViewRules.confirmationDialogCount(inBare: bare(Self.menuWithDialog)) == 1)
        #expect(BudgetViewRules.confirmationDialogCount(inBare: bare(Self.menuWithoutDialog)) == 0)
        #expect(BudgetViewRules.confirmationDialogCount(inBare: bare("// .confirmationDialog(")) == 0)
    }

    @Test("a dialog attached to the Menu is found on the Menu and names the model flag")
    func menuCarriesDialog() {
        let found = BudgetViewRules.menusCarryingDialog(inBare: bare(Self.menuWithDialog))

        #expect(found.count == 1)
        #expect(found.first?.contains("isShowingDeleteConfirmation") == true)
    }

    @Test("a dialog on a List or on a container around the Menu is not attached to the Menu")
    func dialogNotOnMenu() {
        #expect(BudgetViewRules.menusCarryingDialog(inBare: bare(Self.listWithDialog)).isEmpty)
        #expect(BudgetViewRules.menusCarryingDialog(inBare: bare(Self.dialogOnStack)).isEmpty)
        #expect(BudgetViewRules.menusCarryingDialog(inBare: bare(Self.menuWithoutDialog)).isEmpty)
    }

    static let badContainerSamples: [String] = [
        "List { Text(\"a\") }",
        "ScrollView { Text(\"a\") }",
        "Form { Text(\"a\") }",
        "NavigationStack { Text(\"a\") }"
    ]

    static let goodContainerSamples: [String] = [
        "Menu { Text(\"a\") }",
        "Text(\"List of ScrollView and Form\")",
        "let shoppingList = 1",
        "let service: ListService",
        "// List { }"
    ]

    @Test("the container rule fires on List, ScrollView, Form and NavigationStack", arguments: badContainerSamples)
    func containerRuleFires(source: String) {
        #expect(!BudgetViewRules.containerViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    @Test("the container rule allows a Menu, words in literals, look-alike names and comments", arguments: goodContainerSamples)
    func containerRuleAllows(source: String) {
        #expect(BudgetViewRules.containerViolations(inBare: bare(source)).isEmpty, "\(source)")
    }

    // MARK: Destructive

    @Test("the destructive rule needs both the role and the token")
    func destructiveRule() {
        let both: String = "Button(\"Delete\", role: .destructive) { }.foregroundStyle(Color.destructiveColor)"
        let roleOnly: String = "Button(\"Delete\", role: .destructive) { }"
        let tokenOnly: String = "Text(\"Delete\").foregroundStyle(Color.destructiveColor)"

        #expect(BudgetViewRules.destructiveViolations(inCode: code(both)).isEmpty)
        #expect(!BudgetViewRules.destructiveViolations(inCode: code(roleOnly)).isEmpty)
        #expect(!BudgetViewRules.destructiveViolations(inCode: code(tokenOnly)).isEmpty)
    }
}
