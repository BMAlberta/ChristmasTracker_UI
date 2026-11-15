//
//  TypographySourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T2: text scans over the app sources (same approach as the item scans: the
//  source root is found from #filePath, comments are stripped before matching).
//

import Foundation
import Testing

@Suite("Typography source scan Tests")
struct TypographySourceScanTests {

    static let typographyFile = "DesignSystem/Typography/AppTypography.swift"
    static let typographyFolder = "DesignSystem/Typography/"

    /// Files allowed to size a font from a @ScaledMetric identifier (`.system(size: someMetric`).
    /// Each must declare @ScaledMetric and actually use an identifier-sized font, so a stale
    /// entry fails. The first sweep lists the files the T2 inventory names; the implementer
    /// corrects it from reality.
    static let identifierSizeAllowlist: Set<String> = [
        "DesignSystem/Components/EmptyStateView.swift",
        "DesignSystem/Components/ErrorStateView.swift",
        "Features/Profile/Views/ProfileView.swift",
        "Features/Authentication/Views/BiometricSetupView.swift",
        "Features/Authentication/Views/LoginView.swift",
        "Features/Authentication/Views/ForgotPasswordView.swift",
        "Features/Authentication/Views/RegistrationView.swift"
    ]

    static let brandFiles: Set<String> = [
        "Features/Authentication/Views/LoginView.swift",
        "Features/Authentication/Views/RegistrationView.swift",
        "DesignSystem/Components/EmptyStateView.swift",
        "Features/Version/Views/UpdateRequiredView.swift"
    ]

    static let lineLimitFiles: Set<String> = [
        "Features/Purchases/Views/ManagePurchaseView.swift",
        "Features/Purchases/Views/RecordPurchaseFormFields.swift",
        "Features/Items/Components/ItemFormFields.swift"
    ]

    /// Code-only text of every app source file, keyed by path relative to the app folder.
    private func codeByFile() throws -> [String: String] {
        let tree = try #require(ItemSourceTree.load(from: #filePath))
        var result: [String: String] = [:]
        for url in tree.all {
            let text = try String(contentsOf: url, encoding: .utf8)
            result[tree.relativePath(url)] = ItemSourceScan.codeOnly(text)
        }
        try #require(!result.isEmpty)
        return result
    }

    private func hits(_ pattern: String, in code: String) throws -> Bool {
        !(try ItemSourceScan.matchingLines(pattern, in: code)).isEmpty
    }

    private static let numericSize = #"\.system\(\s*size:\s*[0-9]"#
    private static let identifierSize = #"\.system\(\s*size:\s*[A-Za-z_]"#

    @Test("AppTypography.swift holds no fixed size and no appIconHero")
    func typographyFileIsSizeFree() throws {
        let files = try codeByFile()
        let code = try #require(files[Self.typographyFile])
        #expect(!code.contains("Font.system(size:"))
        #expect(!code.contains(".system(size:"))
        #expect(!code.contains("appIconHero"))
    }

    @Test("appIconHero is used nowhere in the app")
    func iconHeroGone() throws {
        let offenders = try codeByFile().filter { $0.value.contains("appIconHero") }.keys.sorted()
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("No numeric .system(size:) literal anywhere in the app sources")
    func noNumericSizes() throws {
        var offenders: [String] = []
        for (path, code) in try codeByFile() {
            for line in try ItemSourceScan.matchingLines(Self.numericSize, in: code) {
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.sorted())")
    }

    @Test("An identifier-sized .system(size:) is allowed only in an allowlisted file that declares @ScaledMetric")
    func identifierSizesAreAllowlisted() throws {
        var offenders: [String] = []
        for (path, code) in try codeByFile() {
            guard try hits(Self.identifierSize, in: code) else { continue }
            if !Self.identifierSizeAllowlist.contains(path) || !code.contains("@ScaledMetric") {
                offenders.append(path)
            }
        }
        #expect(offenders.isEmpty, "\(offenders.sorted())")
    }

    @Test("The allowlist has no stale entries")
    func allowlistHasNoStaleEntries() throws {
        let files = try codeByFile()
        var stale: [String] = []
        for path in Self.identifierSizeAllowlist.sorted() {
            guard let code = files[path] else {
                stale.append("\(path) (missing)")
                continue
            }
            let hasIdentifierSize = try hits(Self.identifierSize, in: code)
            if !code.contains("@ScaledMetric") || !hasIdentifierSize {
                stale.append(path)
            }
        }
        #expect(stale.isEmpty, "\(stale)")
    }

    @Test("appBrand outside the Typography folder appears only in the four brand files, and in each")
    func brandUsage() throws {
        let files = try codeByFile()
        var users: Set<String> = []
        for (path, code) in files where !path.hasPrefix(Self.typographyFolder) {
            if code.contains("appBrand") { users.insert(path) }
        }
        #expect(users == Self.brandFiles, "\(users.sorted())")
    }

    @Test("The serif design is named only in the Typography folder")
    func serifOnlyInTypography() throws {
        var offenders: [String] = []
        for (path, code) in try codeByFile() where !path.hasPrefix(Self.typographyFolder) {
            if try hits(#"\.serif\b"#, in: code) { offenders.append(path) }
        }
        // `where` clauses above use only non-throwing checks.
        #expect(offenders.isEmpty, "\(offenders.sorted())")
    }

    @Test("AppTypography.swift uses the serif design for appBrand")
    func typographyFileHoldsSerif() throws {
        let files = try codeByFile()
        let folderCode = files.filter { $0.key.hasPrefix(Self.typographyFolder) }.values.joined(separator: "\n")
        #expect(folderCode.contains(".serif"))
    }

    @Test("No minimumScaleFactor in Features or DesignSystem")
    func noMinimumScaleFactor() throws {
        var offenders: [String] = []
        for (path, code) in try codeByFile() where path.hasPrefix("Features/") || path.hasPrefix("DesignSystem/") {
            if code.contains(".minimumScaleFactor(") { offenders.append(path) }
        }
        #expect(offenders.isEmpty, "\(offenders.sorted())")
    }

    @Test("lineLimit appears only in the three multi-line field files, and in each")
    func lineLimitUsage() throws {
        var users: Set<String> = []
        for (path, code) in try codeByFile() where path.hasPrefix("Features/") || path.hasPrefix("DesignSystem/") {
            if code.contains(".lineLimit(") { users.insert(path) }
        }
        #expect(users == Self.lineLimitFiles, "\(users.sorted())")
    }
}
