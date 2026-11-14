//
//  BudgetViewScanTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: source scans of the NEW view and model files of the Statistics tab and the budget sheets
//  (the rules are proven on synthetic strings in BudgetViewScanRuleTests):
//
//   - every required file exists (these tests fail until the views and models are written);
//   - the ONLY confirmationDialog is in BudgetCardMenu.swift, attached to the Menu, with no List, ScrollView,
//     Form or NavigationStack in that file, bound to the model's isShowingDeleteConfirmation, with a
//     destructive role and Color.destructiveColor;
//   - DesignSystem tokens only (no raw colors, no foregroundColor, no system fonts, no numeric padding,
//     spacing or frame literals);
//   - no interpolated accessibility identifier; no log or Sentry call; no interpolated error; no GCD or
//     Combine; no force unwrap;
//   - errors only through InlineErrorBanner (no ad-hoc error Text);
//   - StatsView.swift no longer holds the placeholder; it drives the model lifecycle and presents sheets
//     with .sheet(item:); the sheet views dismiss themselves.
//
//  Needs the checkout on disk, which scripts/test.sh has.
//

import Foundation
import Testing

@Suite("Budget view scan Tests")
struct BudgetViewScanTests {

    // MARK: Loading

    private func views(file: String = #filePath) throws -> [ScannedSource] {
        try #require(BudgetViewSources.views(from: file), "Could not find the app source folder")
    }

    private func models(file: String = #filePath) throws -> [ScannedSource] {
        try #require(BudgetViewSources.models(from: file), "Could not find the app source folder")
    }

    private func view(_ relative: String, file: String = #filePath) throws -> ScannedSource {
        let found = try views(file: file).first { $0.path == relative }
        return try #require(found, "\(relative) does not exist")
    }

    private func model(_ relative: String, file: String = #filePath) throws -> ScannedSource {
        let found = try models(file: file).first { $0.path == relative }
        return try #require(found, "\(relative) does not exist")
    }

    private func viewsAndModels(file: String = #filePath) throws -> [ScannedSource] {
        try views(file: file) + models(file: file)
    }

    // MARK: Existence

    @Test("every new view and model file of Story C exists")
    func requiredFilesExist() throws {
        let missing = try #require(BudgetViewSources.missingFiles(from: #filePath), "Could not find the app source folder")

        #expect(missing.isEmpty, "Missing files: \(missing.joined(separator: ", "))")
    }

    // MARK: confirmationDialog

    @Test("the only confirmationDialog in the new views is in BudgetCardMenu.swift, exactly once")
    func dialogOnlyInTheMenuFile() throws {
        var total = 0
        for file in try views() {
            let count = BudgetViewRules.confirmationDialogCount(inBare: file.bare)
            total += count
            if file.path != BudgetViewSources.menuFile {
                #expect(count == 0, "\(file.path) must not hold a confirmationDialog")
            }
        }
        let menu = try view(BudgetViewSources.menuFile)
        #expect(BudgetViewRules.confirmationDialogCount(inBare: menu.bare) == 1)
        #expect(total == 1)
    }

    @Test("no model file presents a confirmationDialog")
    func noDialogInModels() throws {
        for file in try models() {
            #expect(BudgetViewRules.confirmationDialogCount(inBare: file.bare) == 0, "\(file.path)")
        }
    }

    @Test("the dialog is attached to the Menu and bound to the model's isShowingDeleteConfirmation")
    func dialogAttachedToMenu() throws {
        let menu = try view(BudgetViewSources.menuFile)

        let carrying = BudgetViewRules.menusCarryingDialog(inBare: menu.bare)

        #expect(carrying.count == 1, "the Menu declaration must carry the .confirmationDialog( modifier")
        #expect(carrying.first?.contains("isShowingDeleteConfirmation") == true,
                "the dialog is bound to the screen model's flag")
    }

    @Test("BudgetCardMenu.swift has no List, ScrollView, Form or NavigationStack")
    func menuFileHasNoContainers() throws {
        let menu = try view(BudgetViewSources.menuFile)

        #expect(BudgetViewRules.containerViolations(inBare: menu.bare).isEmpty,
                "\(BudgetViewRules.containerViolations(inBare: menu.bare))")
    }

    @Test("the delete button is destructive with Color.destructiveColor")
    func deleteIsDestructive() throws {
        let menu = try view(BudgetViewSources.menuFile)

        #expect(BudgetViewRules.destructiveViolations(inCode: menu.code).isEmpty,
                "\(BudgetViewRules.destructiveViolations(inCode: menu.code))")
    }

    @Test("the menu offers Edit Budget, Duplicate to Another Year and Delete Budget, with the model's delete strings")
    func menuContent() throws {
        let menu = try view(BudgetViewSources.menuFile)

        #expect(menu.code.contains("Edit Budget"))
        #expect(menu.code.contains("Duplicate to Another Year"))
        #expect(menu.code.contains("deleteTitle"), "the dialog title comes from StatsScreenModel.deleteTitle(year:)")
        #expect(menu.code.contains("deleteMessage"), "the dialog message comes from StatsScreenModel.deleteMessage")
        #expect(menu.code.contains("deleteButtonTitle"), "the destructive button uses StatsScreenModel.deleteButtonTitle")
        #expect(menu.code.contains("requestDelete"), "the menu item asks the model to confirm")
        #expect(menu.code.contains("confirmDelete"), "the destructive button confirms through the model")
    }

    // MARK: Design tokens and SwiftUI rules

    @Test("the new views use only DesignSystem tokens")
    func viewsUseTokens() throws {
        for file in try views() {
            let hits = BudgetViewRules.tokenViolations(inBare: file.bare)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("the new views follow the SwiftUI rules of the brief")
    func viewsFollowSwiftUIRules() throws {
        for file in try views() {
            let hits = BudgetViewRules.swiftUIRuleViolations(inBare: file.bare)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    // MARK: Hygiene

    @Test("no accessibility identifier interpolates a value")
    func noInterpolatedIdentifiers() throws {
        for file in try viewsAndModels() {
            let hits = BudgetViewRules.identifierInterpolationViolations(inCode: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no log, print or Sentry call in the new views and models")
    func noLogsOrSentry() throws {
        for file in try viewsAndModels() {
            let hits = BudgetViewRules.logAndSentryViolations(inBare: file.bare)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new view or model interpolates, describes or localizes an error")
    func noRawErrors() throws {
        for file in try viewsAndModels() {
            let hits = BudgetViewRules.errorInterpolationViolations(inCode: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new view or model uses GCD or Combine")
    func noGCDOrCombine() throws {
        for file in try viewsAndModels() {
            let hits = BudgetViewRules.concurrencyViolations(inCode: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new view or model force unwraps")
    func noForceUnwraps() throws {
        for file in try viewsAndModels() {
            let hits = RecordPurchaseViewRules.forceUnwrapViolations(inBare: file.bare)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    // MARK: Errors only through the banner

    @Test("no new view renders an error as ad-hoc Text")
    func noAdHocErrorText() throws {
        for file in try views() {
            let hits = BudgetViewRules.adHocErrorTextViolations(inBare: file.bare)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("the sheets and the Statistics views render their errors with InlineErrorBanner")
    func errorsUseTheBanner() throws {
        let editor = try view(BudgetViewSources.editorViewFile)
        let duplicate = try view(BudgetViewSources.duplicateViewFile)
        let stats = try views().filter { $0.path.hasPrefix("Features/Statistics/Views/") }

        #expect(editor.code.contains("InlineErrorBanner("), "the editor sheet shows its banner")
        #expect(duplicate.code.contains("InlineErrorBanner("), "the duplicate sheet shows its banner")
        #expect(stats.contains { $0.code.contains("InlineErrorBanner(") }, "the Statistics views show their banners")
    }

    // MARK: StatsView

    @Test("StatsView.swift no longer contains the placeholder")
    func placeholderIsGone() throws {
        let statsView = try view(BudgetViewSources.statsViewFile)

        #expect(!statsView.raw.contains("Statistics coming soon"))
        #expect(!statsView.code.contains("EmptyStateView"))
        #expect(statsView.code.contains("struct StatsView"))
    }

    @Test("StatsView drives the model lifecycle, pull to refresh and the sheets")
    func statsViewLifecycle() throws {
        let statsView = try view(BudgetViewSources.statsViewFile)

        #expect(statsView.code.contains(".onAppear"), "appearance is reported to the model")
        #expect(statsView.code.contains("model.onAppear()"))
        #expect(statsView.code.contains(".onDisappear"), "leaving is reported to the model")
        #expect(statsView.code.contains("model.onDisappear()"))
        #expect(statsView.code.contains(".refreshable"), "pull to refresh")
        #expect(statsView.code.contains("model.refresh()"))
        #expect(statsView.code.contains(".sheet(item:"), "sheets use the item form")
        #expect(statsView.code.contains("presentedSheet"), "bound to the model's presentedSheet")
    }

    @Test("the sheet views dismiss themselves")
    func sheetsDismissThemselves() throws {
        for relative in [BudgetViewSources.editorViewFile, BudgetViewSources.duplicateViewFile] {
            let sheet = try view(relative)
            #expect(sheet.code.contains("@Environment(\\.dismiss)"), "\(relative) reads the dismiss action")
            #expect(sheet.code.contains("dismiss()"), "\(relative) calls dismiss()")
        }
    }

    // MARK: Models

    @Test("the screen models are MainActor, Observable and final")
    func modelShape() throws {
        let markers: [(String, String)] = [
            (BudgetViewSources.requiredModels[0], "final class StatsScreenModel"),
            (BudgetViewSources.requiredModels[1], "final class BudgetEditorModel"),
            (BudgetViewSources.requiredModels[2], "final class DuplicateBudgetModel")
        ]
        for (relative, marker) in markers {
            let source = try model(relative)
            #expect(source.code.contains(marker), "\(relative) declares \(marker)")
            #expect(source.code.contains("@MainActor"), "\(relative)")
            #expect(source.code.contains("@Observable"), "\(relative)")
        }
    }

    @Test("the editor and duplicate models take no error property from a service: the banner is their own")
    func modelsHoldTheirOwnBanner() throws {
        for relative in [BudgetViewSources.requiredModels[1], BudgetViewSources.requiredModels[2]] {
            let source = try model(relative)
            #expect(source.code.contains("var banner: InlineErrorBannerState?"), "\(relative)")
        }
        let screen = try model(BudgetViewSources.requiredModels[0])
        #expect(screen.code.contains("var budgetCardBanner: InlineErrorBannerState?"))
        #expect(screen.code.contains("var isShowingDeleteConfirmation"))
    }
}
