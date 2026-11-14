//
//  UX1aErrorScanTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: every error on every screen in scope is an InlineErrorBanner. A text scan over the
//  sources of Features/Lists, Features/Dashboard, Features/Items, Features/Children, Features/Profile,
//  Features/Statistics and Features/Budgets (comments stripped first).
//
//  Rules (a match is an offender):
//   1. no `exclamationmark.triangle.fill` outside InlineErrorBanner (an ad-hoc error row);
//   2. no `.alert(` that shows an error message;
//   3. no view reads a service's shared error: `<name>Service.error` or `.clearError`;
//   4. no use of the removed `ListErrorBanner`, `ErrorStateView`, `ListErrorDismissal`,
//      `ListArchiveCompletion` or `ListDetailRefresh.banner`;
//   5. no ad-hoc Try Again or Retry button: the string literals "Try Again" and "Retry" belong to
//      InlineErrorBannerState (DesignSystem) only;
//   6. positive: each error screen builds its banner with `InlineErrorBanner(` and takes its load
//      presentation from its pure state.
//
//  DOCUMENTED ALLOWLIST AND EXCLUSIONS
//   - Features/Authentication (login, registration, lock keep their own alert and inline error
//     patterns) and App/ConfigurationErrorView.swift are OUT of scope and are not scanned.
//   - Features/Purchases/Views/BudgetWarningPanel.swift uses the icon for a WARNING, not an error. It
//     is outside the scanned folders and is listed in `iconAllowlist` so the exception is explicit
//     and a test keeps it honest (the file must exist).
//   - DesignSystem/ (InlineErrorBanner, ErrorStateView and its previews) is not scanned: the icon
//     lives there by design. ErrorStateView may stay in DesignSystem; no scoped view may use it.
//   - The purchase screens are already conforming and are not scanned (their own scan tests apply).
//
//  Every rule is proven on synthetic strings (it fires on the bad forms and stays quiet on the good
//  ones) before it runs over the real sources. Needs the checkout on disk, which scripts/test.sh has.
//  The on-disk rules scan the real sources and must stay green.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum UX1aErrorScan {

    static let scopeFolders = [
        "Features/Lists/", "Features/Dashboard/", "Features/Items/", "Features/Children/",
        "Features/Profile/", "Features/Statistics/", "Features/Budgets/"
    ]

    /// Files allowed to use the icon: a warning, not an error. Outside the scope folders; kept explicit.
    static let iconAllowlist = ["Features/Purchases/Views/BudgetWarningPanel.swift"]

    // MARK: Patterns

    static let iconPattern = #"exclamationmark\.triangle\.fill"#
    static let alertPattern = #"\.alert\s*\("#
    static let errorWords = #"(?i)(error|fail|couldn|went wrong|try again)"#
    static let sharedErrorPattern = #"\b[A-Za-z]*[sS]ervice\s*\.\s*(error|clearError)\b"#
    static let removedTypesPattern =
        #"\b(ListErrorBanner|ErrorStateView|ListErrorDismissal|ListArchiveCompletion)\b|\bListDetailRefresh\s*\.\s*banner\b"#
    static let adHocRetryPattern = #""(Try Again|Retry)""#

    static func isInScope(_ relativePath: String) -> Bool {
        scopeFolders.contains { relativePath.hasPrefix($0) }
    }

    /// Lines of every `.alert(` whose call text (the next 400 characters) mentions an error.
    static func errorAlertLines(in code: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: alertPattern)
        let whole = NSRange(code.startIndex..., in: code)
        var lines: [Int] = []
        for match in regex.matches(in: code, range: whole) {
            guard let start = Range(match.range, in: code) else { continue }
            let tail = String(code[start.lowerBound...].prefix(400))
            if !(try ItemSourceScan.matchingLines(errorWords, in: tail)).isEmpty {
                lines.append(code.prefix(match.range.location).filter { $0 == "\n" }.count + 1)
            }
        }
        return lines
    }
}

@Suite("UX1a error scan Tests")
struct UX1aErrorScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    private func fires(_ pattern: String, _ source: String) throws -> Bool {
        !(try ItemSourceScan.matchingLines(pattern, in: code(source))).isEmpty
    }

    // MARK: Scanner proofs (synthetic strings)

    @Test("rule 1 fires on an ad-hoc error icon", arguments: [
        #"Label(message, systemImage: "exclamationmark.triangle.fill")"#,
        #"Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)"#,
        "let icon = \"exclamationmark.triangle.fill\""
    ])
    func iconRuleFires(source: String) throws {
        #expect(try fires(UX1aErrorScan.iconPattern, source), "\(source)")
    }

    @Test("rule 1 stays quiet on other icons, the non-filled icon and comments", arguments: [
        #"Image(systemName: "exclamationmark.triangle")"#,
        #"Image(systemName: "arrow.clockwise")"#,
        "// Label with exclamationmark.triangle.fill is gone",
        "InlineErrorBanner(state: banner)"
    ])
    func iconRuleQuiet(source: String) throws {
        #expect(try !fires(UX1aErrorScan.iconPattern, source), "\(source)")
    }

    @Test("rule 2 fires on an alert that shows an error", arguments: [
        ".alert(\"Biometric Setup Failed\", isPresented: $show) { Button(\"OK\") {} } message: { Text(errorMessage) }",
        ".alert(\"Oops\", isPresented: $show) {\n  Button(\"OK\") {}\n} message: {\n  Text(error.userMessage)\n}",
        ".alert(\"Couldn't remove child\", isPresented: $x) { }"
    ])
    func alertRuleFires(source: String) throws {
        #expect(!(try UX1aErrorScan.errorAlertLines(in: code(source))).isEmpty, "\(source)")
    }

    @Test("rule 2 stays quiet on alert words elsewhere and on comments", arguments: [
        "let alertCount = 1",
        "Text(\"alert\")",
        "// .alert(\"Error\", isPresented: $s) { }",
        "Button(\"Archive\") { }"
    ])
    func alertRuleQuiet(source: String) throws {
        #expect(try UX1aErrorScan.errorAlertLines(in: code(source)).isEmpty, "\(source)")
    }

    @Test("rule 3 fires on a read of a service's shared error", arguments: [
        "if let failure = listService.error { show(failure) }",
        "Text(childService.error?.userMessage ?? \"\")",
        "listService.clearError()",
        "environment.itemService.error",
        "statsService . error"
    ])
    func sharedErrorRuleFires(source: String) throws {
        #expect(try fires(UX1aErrorScan.sharedErrorPattern, source), "\(source)")
    }

    @Test("rule 3 stays quiet on the scoped failure values and on comments", arguments: [
        "listService.listsLoadFailure",
        "listService.detailLoadFailure",
        "childService.phase",
        "itemService.listLoadError",
        "itemService.detailLoadError",
        "statsService.failure(forYear: year)",
        "// listService.error is gone",
        "let myService = 1"
    ])
    func sharedErrorRuleQuiet(source: String) throws {
        #expect(try !fires(UX1aErrorScan.sharedErrorPattern, source), "\(source)")
    }

    @Test("rule 4 fires on the removed types", arguments: [
        "ListErrorBanner(error: e, onRetry: r)",
        "struct ListErrorBanner: View {",
        "ErrorStateView(title: t)",
        "var dismissal = ListErrorDismissal()",
        "ListArchiveCompletion.after(serviceError: e)",
        "ListDetailRefresh.banner(for: error)"
    ])
    func removedTypesRuleFires(source: String) throws {
        #expect(try fires(UX1aErrorScan.removedTypesPattern, source), "\(source)")
    }

    @Test("rule 4 stays quiet on the types that stay and on comments", arguments: [
        "ListDetailRefresh.itemsStep(currentItemsListId: a, listId: b)",
        "InlineErrorBanner(state: s)",
        "DismissedLoads()",
        "// ListErrorBanner was removed",
        "let ListErrorBannerCount = 1"
    ])
    func removedTypesRuleQuiet(source: String) throws {
        #expect(try !fires(UX1aErrorScan.removedTypesPattern, source), "\(source)")
    }

    @Test("rule 5 fires on an ad-hoc Try Again or Retry button", arguments: [
        #"Button("Try Again") { reload() }"#,
        #"Label("Try Again", systemImage: "arrow.clockwise")"#,
        #"bannerButton("Retry", action: r)"#
    ])
    func adHocRetryRuleFires(source: String) throws {
        #expect(try fires(UX1aErrorScan.adHocRetryPattern, source), "\(source)")
    }

    @Test("rule 5 stays quiet on the banner action and on comments", arguments: [
        "InlineErrorBannerState(message: m, actions: [.tryAgain, .dismiss])",
        "// Button(\"Try Again\") was removed",
        #"Button("Retry Purchase") { }"#,
        #"Text("Try again later")"#
    ])
    func adHocRetryRuleQuiet(source: String) throws {
        #expect(try !fires(UX1aErrorScan.adHocRetryPattern, source), "\(source)")
    }

    @Test("the scope check accepts the scope folders and rejects Authentication and DesignSystem")
    func scopeCheck() {
        #expect(UX1aErrorScan.isInScope("Features/Lists/Views/ListDetailView.swift"))
        #expect(UX1aErrorScan.isInScope("Features/Dashboard/Views/DashboardView.swift"))
        #expect(UX1aErrorScan.isInScope("Features/Profile/Views/ProfileView.swift"))
        #expect(UX1aErrorScan.isInScope("Features/Budgets/Views/BudgetEditorView.swift"))
        #expect(!UX1aErrorScan.isInScope("Features/Authentication/Views/LoginView.swift"))
        #expect(!UX1aErrorScan.isInScope("Features/Purchases/Views/BudgetWarningPanel.swift"))
        #expect(!UX1aErrorScan.isInScope("DesignSystem/Components/InlineErrorBanner.swift"))
        #expect(!UX1aErrorScan.isInScope("App/ConfigurationErrorView.swift"))
    }

    // MARK: On disk

    private struct Scanned {
        let relative: String
        let code: String
    }

    private func scopedSources(file: String = #filePath) throws -> [Scanned] {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        var result: [Scanned] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard UX1aErrorScan.isInScope(relative) else { continue }
            result.append(Scanned(relative: relative, code: ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        #expect(result.count > 20, "the scan reached only \(result.count) files in the scope folders")
        return result
    }

    private func offenders(_ pattern: String, in sources: [Scanned]) throws -> [String] {
        var found: [String] = []
        for source in sources {
            let lines = try ItemSourceScan.matchingLines(pattern, in: source.code)
            if !lines.isEmpty { found.append("\(source.relative):\(lines)") }
        }
        return found
    }

    @Test("the scan reaches the screens in scope")
    func scopeReachesTheScreens() throws {
        let names = Set(try scopedSources().map { ($0.relative as NSString).lastPathComponent })

        for expected in [
            "DashboardView.swift", "ListDetailView.swift", "CreateListView.swift", "EditListView.swift",
            "AddMemberView.swift", "ChildrenView.swift", "AddChildView.swift", "ItemDetailView.swift",
            "ProfileView.swift", "StatsView.swift", "BudgetEditorView.swift"
        ] {
            #expect(names.contains(expected), "\(expected) is not scanned")
        }
    }

    @Test("the allowlisted warning panel exists, so the exception is not stale")
    func allowlistIsNotStale() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        for relative in UX1aErrorScan.iconAllowlist {
            #expect(tree.exists(relative), "allowlisted file is gone: \(relative)")
        }
    }

    @Test("rule 1: no ad-hoc error icon in the scope folders")
    func noAdHocErrorIcon() throws {
        let found = try offenders(UX1aErrorScan.iconPattern, in: try scopedSources()).filter { entry in
            !UX1aErrorScan.iconAllowlist.contains { entry.hasPrefix($0) }
        }

        #expect(found.isEmpty, "exclamationmark.triangle.fill built outside InlineErrorBanner: \(found)")
    }

    @Test("rule 2: no alert that shows an error in the scope folders")
    func noErrorAlert() throws {
        var found: [String] = []
        for source in try scopedSources() {
            let lines = try UX1aErrorScan.errorAlertLines(in: source.code)
            if !lines.isEmpty { found.append("\(source.relative):\(lines)") }
        }

        #expect(found.isEmpty, "an .alert( shows an error message: \(found)")
    }

    @Test("rule 3: no view reads a service's shared error")
    func noSharedErrorRead() throws {
        let found = try offenders(UX1aErrorScan.sharedErrorPattern, in: try scopedSources())

        #expect(found.isEmpty, "a shared service error is read: \(found)")
    }

    @Test("rule 4: no use of the removed error presentations")
    func noRemovedTypes() throws {
        let found = try offenders(UX1aErrorScan.removedTypesPattern, in: try scopedSources())

        #expect(found.isEmpty, "a removed error type is still used or declared: \(found)")
    }

    @Test("rule 5: no ad-hoc Try Again or Retry button in the scope folders")
    func noAdHocRetryButton() throws {
        let found = try offenders(UX1aErrorScan.adHocRetryPattern, in: try scopedSources())

        #expect(found.isEmpty, "an error action is built outside InlineErrorBanner: \(found)")
    }

    @Test("rule 6: each error screen renders its errors with InlineErrorBanner(")
    func screensUseInlineErrorBanner() throws {
        let sources = try scopedSources()
        for name in [
            "DashboardView.swift", "ListDetailView.swift", "CreateListView.swift", "EditListView.swift",
            "AddMemberView.swift", "ChildrenView.swift", "AddChildView.swift", "ItemDetailView.swift",
            "ProfileView.swift", "StatsView.swift"
        ] {
            let source = try #require(sources.first { ($0.relative as NSString).lastPathComponent == name }, "\(name) missing")
            #expect(source.code.contains("InlineErrorBanner("), "\(name) must render its errors with InlineErrorBanner(")
        }
    }

    @Test("rule 6: the load screens take their presentation from the pure load states")
    func loadScreensUsePureStates() throws {
        let sources = try scopedSources()
        let expectations = [
            ("DashboardView.swift", "DashboardLoadState"),
            ("ListDetailView.swift", "ListDetailLoadState"),
            ("ChildrenView.swift", "ChildrenLoadState"),
            ("ItemDetailView.swift", "ItemDetailLoadState")
        ]
        for (name, stateName) in expectations {
            let source = try #require(sources.first { ($0.relative as NSString).lastPathComponent == name }, "\(name) missing")
            #expect(source.code.contains(stateName), "\(name) must build its load presentation with \(stateName)")
        }
    }
}
