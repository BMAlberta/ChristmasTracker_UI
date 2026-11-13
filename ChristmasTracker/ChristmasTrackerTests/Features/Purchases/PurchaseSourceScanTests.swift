//
//  PurchaseSourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: text-scan evidence over the NEW purchase sources (Domain, ViewState, the new
//  Repositories files and Services). The legacy PurchaseRepository, NetworkPurchaseRepository and
//  MockPurchaseRepository files and the legacy Views and Components were deleted in I4b; the
//  exclusion entry below is kept harmlessly.
//
//  Rules under test (acceptance: "the confirmation token never appears in a log, Sentry, an
//  accessibility identifier, a service property, or any persisted store"; Gate 1 service and
//  repository rules):
//   - no log call interpolates anything, and none mentions a token;
//   - no raw error value is interpolated or described, and no print, NSLog or os_log;
//   - no Sentry data call (setData, setExtra, setTag, breadcrumb, capture) in the service;
//   - no token-named stored property on the service, no persistence APIs in the new sources;
//   - no Double arithmetic on money outside PurchaseMapping.swift (the boundary);
//   - the repository uses @Instrumented, switches without a default, never produces .sessionEnded;
//   - the service uses the manual span "service.purchases.recordPurchase" with an explaining comment.
//
//  The scanner is first proven with synthetic positive and negative strings, then run over the real
//  files. Comments are stripped before matching. The checkout must be on disk (scripts/test.sh has it).
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum PurchaseScan {

    // These files were deleted in I4b; the entries are kept harmlessly.
    static let legacyFiles: Set<String> = [
        "PurchaseRepository.swift", "NetworkPurchaseRepository.swift", "MockPurchaseRepository.swift"
    ]

    /// Violations are returned as short descriptions (rule + 1-based line).
    static func logViolations(in code: String) -> [String] {
        var found: [String] = []
        let rules: [(String, String)] = [
            ("log call with an interpolation", #"\bLog[A-Za-z]*\([^\n]*\\\("#),
            ("log call mentioning a token", #"\bLog[A-Za-z]*\([^\n]*[Tt]oken"#),
            ("print, NSLog or os_log", #"\b(print|NSLog|os_log|debugPrint)\("#)
        ]
        for (name, pattern) in rules {
            for line in (try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1] {
                found.append("\(name) at line \(line)")
            }
        }
        return found
    }

    static func rawErrorViolations(in code: String) -> [String] {
        var found: [String] = []
        let rules: [(String, String)] = [
            ("interpolated error", #"\\\(\s*(error|err|cause)\b"#),
            ("described error", #"String\((describing|reflecting):\s*(error|err|cause)\b"#),
            ("error.localizedDescription", #"\b(error|err|cause)\.localizedDescription\b"#)
        ]
        for (name, pattern) in rules {
            for line in (try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1] {
                found.append("\(name) at line \(line)")
            }
        }
        return found
    }

    static func sentryDataViolations(in code: String) -> [String] {
        let pattern = #"\.(setData|setExtra|setTag|addBreadcrumb|capture)\(|SentrySDK\.capture|\bBreadcrumb\("#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "sentry data call at line \($0)" }
    }

    static func tokenPropertyViolations(in code: String) -> [String] {
        // A type-scope stored property (4 spaces of indentation) whose name mentions a token.
        let pattern = #"(?m)^    (private(\(set\))? |fileprivate |internal |public )?(nonisolated\(unsafe\) )?(var|let)\s+\w*[Tt]oken"#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "token property at line \($0)" }
    }

    static func persistenceViolations(in code: String) -> [String] {
        let pattern = #"UserDefaults|@AppStorage|@SceneStorage|Keychain|NetworkCache|ItemDataStore|ListDataStore|FileManager|\.write\(to|NSUbiquitous"#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "persistence API at line \($0)" }
    }

    static func doubleViolations(in code: String) -> [String] {
        let pattern = #"\bDouble\b|\.doubleValue\b|\bFloat\b|\bCGFloat\b"#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "floating point at line \($0)" }
    }

    static func accessibilityTokenViolations(in code: String) -> [String] {
        let pattern = #"accessibility(Identifier|Label|Value|Hint)\([^\n]*[Tt]oken"#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "accessibility text with a token at line \($0)" }
    }
}

@Suite("Purchase source scan Tests")
struct PurchaseSourceScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner proof (synthetic strings)

    @Test("the log rule fires on interpolation, token mentions and print calls", arguments: [
        #"LogError("record failed for \(itemId)", category: .business)"#,
        #"LogInfo("sent \(token)", category: .business)"#,
        #"LogDebug("token ready", category: .business)"#,
        #"print("hello")"#,
        #"NSLog("x")"#
    ])
    func logRuleFires(source: String) {
        #expect(!PurchaseScan.logViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the log rule does not fire on a plain literal, a comment or look-alike names", arguments: [
        #"LogError("record purchase failed", category: .business)"#,
        #"// LogError("failed \(token)", category: .business)"#,
        "let blogPost = 1",
        #"let printer = 2"#
    ])
    func logRuleDoesNotFire(source: String) {
        #expect(PurchaseScan.logViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the raw error rule fires on an interpolated, described or localized error", arguments: [
        #"LogError("failed: \(error)")"#,
        "let text = String(describing: error)",
        "let text = String(reflecting: error)",
        "let text = error.localizedDescription"
    ])
    func rawErrorRuleFires(source: String) {
        #expect(!PurchaseScan.rawErrorViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the raw error rule does not fire on a type check, a comment or a different name", arguments: [
        "if let typed = error as? PurchaseError { throw typed }",
        "throw PurchaseError.server",
        "// String(describing: error) is never used",
        "let errorCount = 1"
    ])
    func rawErrorRuleDoesNotFire(source: String) {
        #expect(PurchaseScan.rawErrorViolations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("the token property rule fires on a stored property and not on a parameter or a local", arguments: [
        ("    private var pendingToken: String?", true),
        ("    var confirmationToken = \"\"", true),
        ("    let token: String", true),
        ("    func record(confirmationToken: String?) async throws {", false),
        ("        let token = confirmationToken", false),
        ("    // private var pendingToken: String?", false)
    ])
    func tokenPropertyRule(source: String, fires: Bool) {
        #expect(PurchaseScan.tokenPropertyViolations(in: code(source)).isEmpty == !fires, "\(source)")
    }

    @Test("the persistence and floating point rules fire on their APIs", arguments: [
        "UserDefaults.standard.set(token, forKey: \"t\")", "@AppStorage(\"t\") var t = \"\"",
        "let cache = NetworkCache.shared", "let x = Double(amount)", "let y: Double = 1", "let z = value.doubleValue"
    ])
    func storageAndFloatRulesFire(source: String) {
        let hits = PurchaseScan.persistenceViolations(in: code(source)) + PurchaseScan.doubleViolations(in: code(source))
        #expect(!hits.isEmpty, "\(source)")
    }

    // MARK: Real sources

    private func newSources(file: String = #filePath) throws -> [(path: String, code: String)] {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        var result: [(path: String, code: String)] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/Purchases/") else { continue }
            let isNewFolder = ["Domain/", "ViewState/", "Repositories/", "Services/"]
                .contains { relative.hasPrefix("Features/Purchases/\($0)") }
            guard isNewFolder, !PurchaseScan.legacyFiles.contains(url.lastPathComponent) else { continue }
            let raw = try String(contentsOf: url, encoding: .utf8)
            result.append((relative, ItemSourceScan.codeOnly(raw)))
        }
        return result
    }

    private func source(containing marker: String, file: String = #filePath) throws -> (path: String, raw: String, code: String) {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard !relative.hasPrefix("Features/Purchases/Views/"),
                  !relative.hasPrefix("Features/Purchases/Components/"),
                  !PurchaseScan.legacyFiles.contains(url.lastPathComponent) else {
                continue
            }
            let raw = try String(contentsOf: url, encoding: .utf8)
            let stripped = ItemSourceScan.codeOnly(raw)
            if stripped.contains(marker) { return (relative, raw, stripped) }
        }
        Issue.record("no purchase source contains \(marker)")
        throw CocoaError(.fileNoSuchFile)
    }

    @Test("the new purchase sources exist: the protocol, the repository, the mock recorder and the service")
    func newSourcesExist() throws {
        _ = try source(containing: "protocol PurchaseRecording")
        _ = try source(containing: "final class GeneratedClientPurchaseRepository")
        _ = try source(containing: "actor MockPurchaseRecorder")
        _ = try source(containing: "final class PurchaseService")
    }

    @Test("no new purchase source logs an interpolation, a token, or uses print")
    func noUnsafeLogging() throws {
        for (path, code) in try newSources() {
            let hits = PurchaseScan.logViolations(in: code)
            #expect(hits.isEmpty, "\(path): \(hits)")
        }
    }

    @Test("the service and the repository never interpolate or describe a raw error value")
    func noRawErrors() throws {
        let service = try source(containing: "final class PurchaseService")
        let repository = try source(containing: "final class GeneratedClientPurchaseRepository")
        let mock = try source(containing: "actor MockPurchaseRecorder")

        for file in [service, repository, mock] {
            let hits = PurchaseScan.rawErrorViolations(in: file.code)
            #expect(hits.isEmpty, "\(file.path): \(hits)")
        }
    }

    @Test("the repository and the mapping do not log at all")
    func repositoryDoesNotLog() throws {
        let repository = try source(containing: "final class GeneratedClientPurchaseRepository")
        let mapping = try source(containing: "func mapRecordedPurchase")

        for file in [repository, mapping] {
            let calls = try ItemSourceScan.matchingLines(#"\bLog[A-Za-z]*\("#, in: file.code)
            #expect(calls.isEmpty, "\(file.path) logs at lines \(calls)")
        }
    }

    @Test("the service logs at most plain operation names and sends no data to Sentry")
    func serviceLoggingAndSentry() throws {
        let service = try source(containing: "final class PurchaseService")

        #expect(PurchaseScan.sentryDataViolations(in: service.code).isEmpty,
                "\(PurchaseScan.sentryDataViolations(in: service.code))")
        #expect(PurchaseScan.logViolations(in: service.code).isEmpty, "\(PurchaseScan.logViolations(in: service.code))")
    }

    @Test("no purchase source stores a token in a property")
    func noTokenProperty() throws {
        for (path, code) in try newSources() {
            // The flow, the pending confirmation and the outcome hold the token by design (in memory,
            // redacted), and the mock plays the server that issues tokens; every other new source
            // (the service, the real and inert repositories, the domain and form files) must not.
            let allowed = path.hasSuffix("RecordPurchaseFlow.swift") || path.hasSuffix("PurchaseOutcome.swift")
                || code.contains("actor MockPurchaseRecorder")
            if allowed { continue }
            let hits = PurchaseScan.tokenPropertyViolations(in: code)
            #expect(hits.isEmpty, "\(path): \(hits)")
        }
    }

    @Test("the service source has no token-named stored property")
    func serviceHasNoTokenProperty() throws {
        let service = try source(containing: "final class PurchaseService")

        #expect(PurchaseScan.tokenPropertyViolations(in: service.code).isEmpty)
        #expect(!service.code.contains("storedToken"))
    }

    @Test("no new purchase source touches a persisted store")
    func noPersistence() throws {
        for (path, code) in try newSources() {
            let hits = PurchaseScan.persistenceViolations(in: code)
            #expect(hits.isEmpty, "\(path): \(hits)")
        }
    }

    @Test("no accessibility text in the purchase sources mentions a token")
    func noTokenInAccessibility() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath))
        for url in tree.all where tree.relativePath(url).hasPrefix("Features/Purchases/") {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let hits = PurchaseScan.accessibilityTokenViolations(in: code)
            #expect(hits.isEmpty, "\(tree.relativePath(url)): \(hits)")
        }
    }

    @Test("no Double arithmetic on money in the new purchase sources (the mapping boundary is the one exception)")
    func noDoubleOnMoney() throws {
        for (path, code) in try newSources() where !path.hasSuffix("PurchaseMapping.swift") {
            let hits = PurchaseScan.doubleViolations(in: code)
            #expect(hits.isEmpty, "\(path): \(hits)")
        }
    }

    @Test("the repository is @Instrumented, has no default case and never produces sessionEnded")
    func repositoryShape() throws {
        let repository = try source(containing: "final class GeneratedClientPurchaseRepository")

        #expect(repository.code.contains("@Instrumented"))
        #expect(!repository.code.contains("default:"), "every Output case must be explicit")
        #expect(!repository.code.contains("sessionEnded"))
        #expect(repository.code.contains("decimalToDouble"), "money leaves through the package helper")
    }

    @Test("the service uses the manual span with an explaining comment and not the macro")
    func serviceUsesManualSpan() throws {
        let service = try source(containing: "final class PurchaseService")

        #expect(service.code.contains("service.purchases.recordPurchase"))
        #expect(!service.code.contains("@Instrumented"), "a @MainActor method uses a manual span instead")
        #expect(service.raw.contains("Instrumented"), "a comment explains why the macro is not used")
    }

    @Test("the service conforms to SessionClearable and exposes no error property")
    func serviceShape() throws {
        let service = try source(containing: "final class PurchaseService")

        #expect(service.code.contains("SessionClearable"))
        let errorProperties = try ItemSourceScan.matchingLines(#"(?m)^    (private(\(set\))? )?var\s+\w*[Ee]rror\w*\s*[:=]"#, in: service.code)
        #expect(errorProperties.isEmpty, "PurchaseService must not publish an error (lines \(errorProperties))")
    }

    @Test("the mock recorder is an actor and the inert recorder throws clientUnavailable")
    func inertAndMockShape() throws {
        let mock = try source(containing: "actor MockPurchaseRecorder")
        let inert = try source(containing: "final class InertPurchaseRecorder")
        let inertBody = try #require(ItemSourceScan.braceBody(after: "final class InertPurchaseRecorder", in: inert.code))

        #expect(mock.code.contains("PurchaseRecording"))
        #expect(inertBody.contains("clientUnavailable"))
    }
}
