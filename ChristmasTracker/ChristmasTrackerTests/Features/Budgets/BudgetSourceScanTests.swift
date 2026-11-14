//
//  BudgetSourceScanTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: source scans of the NEW production files under Features/Statistics and Features/Budgets
//  (Repositories and Services folders):
//
//   - no log call interpolates a value (an amount, a name, an id, an error) or logs a non-literal;
//   - no Sentry data call, and no Sentry transaction call that interpolates a value;
//   - no raw error is interpolated, described or localized; no print;
//   - no GCD and no Combine;
//   - no persistence API (the caches live in memory and are emptied at teardown);
//   - every `async throws` function of the two generated repositories carries @Instrumented;
//   - the failure funnel files (the repositories) have no `default:` in their switches, never produce
//     sessionEnded, and convert money through the package helpers;
//   - the services use manual spans named service.stats.* and service.budgets.* with an explaining
//     comment, conform to SessionClearable and SpendingCacheInvalidating, keep a private generation,
//     and publish no shared error property (BudgetService has none at all; StatsService only has
//     `loadFailure`).
//
//  Each rule is proven on in-memory strings before it runs on disk. Needs the checkout on disk, which
//  scripts/test.sh has.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Budget source scan Tests")
struct BudgetSourceScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner proofs (synthetic strings)

    @Test("the log rule fires on interpolated amounts, names, ids and errors and on non-literals", arguments: [
        #"LogInfo("Created budget \(budget.id)", category: .business)"#,
        #"LogInfo("Total \(total)", category: .business)"#,
        #"LogDebug("Person \(name)", category: .business)"#,
        #"LogError("failed: \(error)")"#,
        "LogInfo(\n    \"split \\(amount)\",\n    category: .business\n)",
        "LogError(message, category: .business)",
        "LogDebug(error.localizedDescription)"
    ])
    func logRuleFires(source: String) throws {
        #expect(!(try PurchaseLogScan.violations(in: code(source))).isEmpty, "\(source)")
    }

    @Test("the log rule allows static strings and comments", arguments: [
        #"LogError("load stats failed", category: .business)"#,
        "LogInfo(\n    \"split across lines\",\n    category: .business\n)",
        #"// LogInfo("Created budget \(budget.id)")"#,
        "let blogPost = 1"
    ])
    func logRuleAllows(source: String) throws {
        #expect(try PurchaseLogScan.violations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the Sentry rule fires on data calls and interpolated transaction arguments", arguments: [
        #"transaction.setData(value: total, key: "total")"#,
        #"span.setTag(value: name, key: "name")"#,
        #"SentrySDK.capture(error: error)"#,
        #"SentrySDK.addBreadcrumb(crumb)"#,
        #"let t = SentrySDK.startTransaction(name: "service.budgets.create.\(year)", operation: "x")"#,
        "let t = SentrySDK.startTransaction(\n    name: \"service.budgets.\\(id)\",\n    operation: \"x\"\n)"
    ])
    func sentryRuleFires(source: String) {
        #expect(!BudgetScan.sentryViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the Sentry rule allows constant names, finishing a span and comments", arguments: [
        #"let t = SentrySDK.startTransaction(name: "service.budgets.create", operation: "service")"#,
        "transaction.finish()",
        "transaction.finish(status: .internalError)",
        #"// span.setData(value: total, key: "total")"#
    ])
    func sentryRuleAllows(source: String) {
        #expect(BudgetScan.sentryViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the raw error rule fires on an interpolated, described or localized error and on print", arguments: [
        #"LogError("failed: \(error)")"#,
        "let text = String(describing: error)",
        "let text = String(reflecting: error)",
        "let text = error.localizedDescription",
        #"print("hello")"#
    ])
    func rawErrorRuleFires(source: String) {
        #expect(!BudgetScan.rawErrorViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the raw error rule allows a type check, a comment and look-alike names", arguments: [
        "if let typed = error as? BudgetError { throw typed }",
        "throw BudgetError.server",
        "// String(describing: error) is never used",
        "let errorCount = 1",
        "let printer = 2"
    ])
    func rawErrorRuleAllows(source: String) {
        #expect(BudgetScan.rawErrorViolations(in: code(source)).isEmpty, "\(source)")
    }

    static let concurrencyCases: [(String, Bool)] = {
        let dispatchPrefix: String = "Dispatch"
        let queueSuffix: String = "Queue"
        let groupSuffix: String = "Group"
        let combineWord: String = "Comb" + "ine"
        let queueLine: String = "let q = " + dispatchPrefix + queueSuffix + ".main"
        let importLine: String = "import " + combineWord
        let groupLine: String = "let g = " + dispatchPrefix + groupSuffix + "()"
        let taskLine: String = "let task = Task { await work() }"
        let actorLine: String = "actor MockBudgetStore {}"
        return [
            (queueLine, true),
            (importLine, true),
            (groupLine, true),
            (taskLine, false),
            (actorLine, false)
        ]
    }()

    @Test("the concurrency rule fires on GCD and Combine and allows async and actors", arguments: concurrencyCases)
    func concurrencyRule(source: String, fires: Bool) {
        #expect(BudgetScan.concurrencyViolations(in: code(source)).isEmpty == !fires, "\(source)")
    }

    @Test("the default rule fires on a default case and allows a dictionary default and comments", arguments: [
        ("switch output {\n    case .ok: break\n    default: break\n}", true),
        ("switch output {\n    case .ok: break\n    default:\n        break\n}", true),
        ("let x = cache[year, default: 0]", false),
        ("// default: is never used", false)
    ])
    func defaultRule(source: String, fires: Bool) {
        #expect(BudgetScan.defaultCaseViolations(in: code(source)).isEmpty == !fires, "\(source)")
    }

    @Test("the instrumented rule fires on an async throws function without @Instrumented", arguments: [
        "    func yearStats(year: Int) async throws -> StatsYear {\n        try await run()\n    }",
        "    @Instrumented\n    func a() async throws {}\n\n\n\n    func b() async throws {}",
        "    func delete(\n        year: Int\n    ) async throws {\n    }"
    ])
    func instrumentedRuleFires(source: String) {
        #expect(!BudgetScan.uninstrumentedAsyncThrows(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the instrumented rule allows @Instrumented, other signatures and comments", arguments: [
        "    @Instrumented\n    func yearStats(year: Int) async throws -> StatsYear {\n        try await run()\n    }",
        "    @Instrumented\n    func delete(\n        year: Int\n    ) async throws {\n    }",
        "    func sync() throws {}",
        "    func later() async {}",
        "    private func classify(_ error: any Error) -> BudgetError { .server }"
    ])
    func instrumentedRuleAllows(source: String) {
        #expect(BudgetScan.uninstrumentedAsyncThrows(in: code(source)).isEmpty, "\(source)")
    }

    // MARK: Real sources

    private func sources(file: String = #filePath) throws -> [(path: String, raw: String, code: String)] {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        var result: [(path: String, raw: String, code: String)] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard BudgetScan.folders.contains(where: { relative.hasPrefix($0) }) else { continue }
            let raw = try String(contentsOf: url, encoding: .utf8)
            result.append((relative, raw, ItemSourceScan.codeOnly(raw)))
        }
        return result
    }

    private func source(containing marker: String, file: String = #filePath) throws -> (path: String, raw: String, code: String) {
        let found = try sources(file: file).first { $0.code.contains(marker) }
        return try #require(found, "no scanned source contains \(marker)")
    }

    @Test("the new sources exist: protocols, repositories, services, the mock store and the invalidator")
    func newSourcesExist() throws {
        _ = try source(containing: "protocol StatsLoading")
        _ = try source(containing: "protocol BudgetManaging")
        _ = try source(containing: "final class GeneratedClientStatsRepository")
        _ = try source(containing: "final class GeneratedClientBudgetRepository")
        _ = try source(containing: "final class StatsService")
        _ = try source(containing: "final class BudgetService")
        _ = try source(containing: "actor MockBudgetStore")
        #expect(try sources().count >= 8)
    }

    @Test("no log call in the new sources interpolates a value or logs a non-literal message")
    func logsOnlyStaticStrings() throws {
        var found: [String] = []
        for file in try sources() {
            for violation in try PurchaseLogScan.violations(in: file.code) {
                found.append("\(file.path): \(violation)")
            }
        }
        #expect(found.isEmpty, "Log calls must be static strings:\n\(found.joined(separator: "\n"))")
    }

    @Test("no Sentry data call and no interpolated Sentry transaction in the new sources")
    func sentryHygiene() throws {
        for file in try sources() {
            let hits = BudgetScan.sentryViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new source interpolates, describes or localizes a raw error, or uses print")
    func noRawErrors() throws {
        for file in try sources() {
            let hits = BudgetScan.rawErrorViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new source uses GCD or Combine")
    func noGCDOrCombine() throws {
        for file in try sources() {
            let hits = BudgetScan.concurrencyViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("no new source touches a persisted store")
    func noPersistence() throws {
        for file in try sources() {
            let hits = BudgetScan.persistenceViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    // MARK: Repositories

    @Test("every async throws function of the generated repositories carries @Instrumented")
    func repositoriesAreInstrumented() throws {
        for marker in ["final class GeneratedClientStatsRepository", "final class GeneratedClientBudgetRepository"] {
            let repository = try source(containing: marker)
            #expect(repository.code.contains("@Instrumented"), "\(repository.path) uses the macro")
            let missing = BudgetScan.uninstrumentedAsyncThrows(in: repository.code)
            #expect(missing.isEmpty, "\(repository.path) has async throws functions without @Instrumented: \(missing)")
        }
    }

    @Test("the repositories have no default case, handle undocumented statuses and never produce sessionEnded")
    func repositoryFunnelShape() throws {
        for marker in ["final class GeneratedClientStatsRepository", "final class GeneratedClientBudgetRepository"] {
            let repository = try source(containing: marker)
            #expect(BudgetScan.defaultCaseViolations(in: repository.code).isEmpty,
                    "\(repository.path): every Output case must be explicit")
            #expect(repository.code.contains("undocumented"), "\(repository.path) maps the undocumented statuses")
            #expect(!repository.code.contains("sessionEnded"), "\(repository.path) never produces sessionEnded")
            #expect(repository.code.contains("TrackerAPIError"), "\(repository.path) classifies thrown package errors")
        }
    }

    @Test("every repository-folder file that switches over an Output or TrackerAPIError has no default case")
    func funnelFilesHaveNoDefault() throws {
        var checked = 0
        for file in try sources() where file.path.contains("/Repositories/") {
            guard file.code.contains("undocumented") || file.code.contains("TrackerAPIError") else { continue }
            checked += 1
            let hits = BudgetScan.defaultCaseViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
        #expect(checked >= 2, "both generated repositories are scanned")
    }

    @Test("the budget repository converts money through the package helpers")
    func budgetRepositoryMoney() throws {
        let repository = try source(containing: "final class GeneratedClientBudgetRepository")

        #expect(repository.code.contains("decimalToDouble"), "money leaves through the package helper")
    }

    @Test("the stats repository reads the year as a decimal string and never builds the all scope")
    func statsRepositoryQuery() throws {
        let repository = try source(containing: "final class GeneratedClientStatsRepository")

        #expect(repository.code.contains("String(year)") || repository.code.contains("\\(year)"),
                "the year query is the decimal string of the year")
        #expect(!repository.code.contains("\"all\""), "the all scope is never requested")
    }

    // MARK: Services

    @Test("the services use manual spans, explain why the macro is not used and are session clearables")
    func servicesUseManualSpans() throws {
        let stats = try source(containing: "final class StatsService")
        let budgets = try source(containing: "final class BudgetService")

        #expect(stats.code.contains("service.stats."))
        #expect(budgets.code.contains("service.budgets."))
        for service in [stats, budgets] {
            #expect(!service.code.contains("@Instrumented"), "\(service.path): a @MainActor method uses a manual span")
            #expect(service.raw.contains("Instrumented"), "\(service.path): a comment explains why the macro is not used")
            #expect(service.code.contains("SessionClearable"), "\(service.path)")
            #expect(service.code.contains("SpendingCacheInvalidating"), "\(service.path)")
            #expect(service.code.contains("@MainActor"), "\(service.path)")
            #expect(service.code.contains("@Observable"), "\(service.path)")
            #expect(service.code.contains("private var generation"), "\(service.path)")
            #expect(service.code.contains("var sessionGeneration: Int"), "\(service.path)")
        }
    }

    @Test("BudgetService has no error property at all and StatsService only has loadFailure")
    func servicesPublishNoSharedError() throws {
        let stats = try source(containing: "final class StatsService")
        let budgets = try source(containing: "final class BudgetService")
        let pattern = #"(?m)^    (private(\(set\))? )?var\s+\w*([Ee]rror|[Ff]ailure)\w*\s*[:=]"#

        let budgetErrors = try ItemSourceScan.matchingLines(pattern, in: budgets.code)
        let statsErrors = try ItemSourceScan.matchingLines(pattern, in: stats.code)

        #expect(budgetErrors.isEmpty, "BudgetService must not publish an error (lines \(budgetErrors))")
        #expect(statsErrors.count == 1, "StatsService publishes exactly loadFailure (lines \(statsErrors))")
        // EDITED (UX1a U2): the declaration is now keyed by year (StatsLoadFailure(year:error:)); it is
        // still the one and only stored property named *Error*/*Failure* in StatsService.
        #expect(stats.code.contains("loadFailure: StatsLoadFailure?"))
        #expect(!stats.code.contains("loadFailure: BudgetError?"), "the BudgetError-typed property is replaced")
    }

    @Test("the budget service's mutation methods are throwing and its load returns the failure")
    func budgetServiceSignatures() throws {
        let budgets = try source(containing: "final class BudgetService")

        #expect(budgets.code.contains("func create(_ request: CreateBudgetRequest) async throws -> Budget"))
        #expect(budgets.code.contains("func update(_ request: UpdateBudgetRequest) async throws -> Budget"))
        #expect(budgets.code.contains("func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget"))
        #expect(budgets.code.contains("func delete(year: Int) async throws"))
        #expect(budgets.code.contains("func loadBudgets(force: Bool) async -> BudgetError?"))
    }

    @Test("the concrete invalidator exists and is a MainActor class over both services")
    func invalidatorShape() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        var found = false
        for url in tree.all {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            guard code.contains("final class SpendingCacheInvalidator") else { continue }
            found = true
            #expect(code.contains("@MainActor"))
            #expect(code.contains("SpendingCacheInvalidating"))
            #expect(code.contains("statsService"))
            #expect(code.contains("budgetService"))
        }
        #expect(found, "SpendingCacheInvalidator is declared")
    }
}
