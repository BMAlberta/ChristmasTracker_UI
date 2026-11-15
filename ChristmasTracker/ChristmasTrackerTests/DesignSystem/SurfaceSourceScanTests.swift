//
//  SurfaceSourceScanTests.swift
//  ChristmasTrackerTests
//
//  TH1-T4: source scans for surfaces, cards and list rows. Comments are stripped before matching.
//  Scanned: Features/, DesignSystem/, App/, Navigation/ (DesignSystem/Colors/ is the token definition and is excluded
//  from the color scans).
//
//  `.white` allowlist (same as StatusStyleScanTests.whiteAllowlist): ItemStatusStyle.swift, ThemeTokenTable.swift only
//  (T5 replaced the hand-built filled buttons with PrimaryButtonStyle). `.clear` is allowed everywhere.
//
//  Hand-built card allowlist (a file may contain `surfaceColor` together with a shape; the implementer corrects it from
//  reality, and stale entries fail):
//   - LoginView.swift          field style and biometric button
//   - RegistrationView.swift   field style
//   - ListComponents.swift     archived badge stroke
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Surface source scans")
struct SurfaceSourceScanTests {

    static let handBuiltCardAllowlist: Set<String> = [
        "Features/Authentication/Views/LoginView.swift",
        "Features/Authentication/Views/RegistrationView.swift",
        "Features/Lists/Views/ListComponents.swift"
    ]

    private static let scopedPrefixes = ["Features/", "DesignSystem/", "App/", "Navigation/"]

    private func tree(_ file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    /// (relative path, code-only source) for every app file under the given prefixes.
    private func sources(in tree: ItemSourceTree, prefixes: [String] = SurfaceSourceScanTests.scopedPrefixes) throws -> [(path: String, code: String)] {
        var result: [(String, String)] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard prefixes.contains(where: { relative.hasPrefix($0) }) else { continue }
            result.append((relative, ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        return result
    }

    private func code(_ relative: String, in tree: ItemSourceTree) throws -> String {
        let text = try #require(tree.source(relative), "\(relative) is missing")
        return ItemSourceScan.codeOnly(text)
    }

    // MARK: 1. System color literals

    @Test func noSystemColorLiteralsOutsideTheTokenDefinitions() throws {
        let patterns = [
            #"\.(red|green|orange|blue|purple|gray|yellow|pink|black)\b"#,
            #"Color\(\s*red:"#,
            #"Color\(\s*white:"#,
            #"Color\(\s*hex"#,
            ##""#[0-9A-Fa-f]{3,8}""##,
            #"UIColor\.system"#,
            #"Color\(\s*uiColor:"#,
            #"Color\(\s*UIColor"#
        ]
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where !path.hasPrefix("DesignSystem/Colors/") {
            for pattern in patterns {
                for line in try ItemSourceScan.matchingLines(pattern, in: code) {
                    offenders.append("\(path):\(line) (\(pattern))")
                }
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test func whiteAppearsOnlyInTheAllowlistedFiles() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where !StatusStyleScanTests.whiteAllowlist.contains(path) {
            for line in try ItemSourceScan.matchingLines(#"\.white\b"#, in: code) {
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 2. Opacity-derived colors

    @Test func opacityOnAColorIsOnlyDerivedFromAThemeToken() throws {
        let allowed: Set<String> = [
            "destructiveColor", "primaryColor", "highlightColor", "backgroundSecondaryColor", "borderColor"
        ]
        let regex = try NSRegularExpression(pattern: #"\.(\w+)\.opacity\("#)
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where !path.hasPrefix("DesignSystem/Colors/") {
            let whole = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: whole) {
                guard let range = Range(match.range(at: 1), in: code) else { continue }
                let receiver = String(code[range])
                if !allowed.contains(receiver) {
                    let line = code.prefix(match.range.location).filter { $0 == "\n" }.count + 1
                    offenders.append("\(path):\(line) .\(receiver).opacity(")
                }
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 3. No shadow

    @Test func noShadowAnywhereInTheAppSources() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree(), prefixes: ["Features/", "DesignSystem/", "App/"]) {
            for line in try ItemSourceScan.matchingLines(#"\.shadow\("#, in: code) {
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 4. Hand-built cards

    private func handBuilds(_ code: String) -> Bool {
        code.contains("surfaceColor")
            && (code.contains("RoundedRectangle(") || code.contains(".clipShape(") || code.contains(".cornerRadius("))
    }

    @Test func handBuiltCardsExistOnlyInAppCardAndTheAllowlist() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree(), prefixes: ["Features/", "DesignSystem/"]) {
            guard path != "DesignSystem/Components/AppCard.swift" else { continue }
            guard !Self.handBuiltCardAllowlist.contains(path) else { continue }
            if handBuilds(code) { offenders.append(path) }
        }
        #expect(offenders.isEmpty, "Use .appCard(): \(offenders.joined(separator: "\n"))")
    }

    @Test func handBuiltCardAllowlistHasNoStaleEntries() throws {
        let tree = try tree()
        var stale: [String] = []
        for path in Self.handBuiltCardAllowlist.sorted() {
            let code = try code(path, in: tree)
            if !handBuilds(code) { stale.append(path) }
        }
        #expect(stale.isEmpty, "Stale allowlist entries: \(stale.joined(separator: "\n"))")
    }

    @Test func appCardFileDefinesTheCardWithThemeTokensAndNoShadow() throws {
        let source = try code("DesignSystem/Components/AppCard.swift", in: try tree())
        #expect(source.contains("func appCard"))
        #expect(source.contains("Color.surfaceColor"))
        #expect(source.contains("Color.borderColor"))
        #expect(source.contains("AppCardStyle.cornerRadius"))
        #expect(source.contains("AppCardStyle.borderWidth"))
        #expect(source.contains("AppCardStyle.padding"))
        #expect(source.contains(".continuous"))
        #expect(!source.contains(".shadow("))
    }

    // MARK: 5. appCard() adoption

    @Test func formerHandBuiltCardFilesUseAppCard() throws {
        let tree = try tree()
        let files = [
            "Features/Dashboard/Components/ListPreviewCard.swift",
            "Features/Items/Views/ItemDetailView.swift",
            "Features/Profile/Views/ProfileView.swift",
            "DesignSystem/Components/Loading/SkeletonView.swift",
            "DesignSystem/Components/Loading/LoadingView.swift"
        ]
        for file in files {
            #expect(try code(file, in: tree).contains(".appCard()"), "\(file) does not use .appCard()")
        }
    }

    @Test func statsCardsUseAppCard() throws {
        let tree = try tree()
        let files = [
            "Features/Statistics/Views/StatsSummaryCardView.swift",
            "Features/Statistics/Views/BudgetCardView.swift",
            "Features/Statistics/Views/SpendByPersonView.swift"
        ]
        var users = 0
        for file in files {
            if try code(file, in: tree).contains(".appCard()") { users += 1 }
        }
        #expect(users >= 1, "None of the Stats card files uses .appCard()")
        #expect(try code("Features/Statistics/Views/StatsSummaryCardView.swift", in: tree).contains(".appCard()"))
    }

    @Test func listCardAndStatsCardStyleAreGone() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) {
            if code.contains("func listCard") { offenders.append("\(path): func listCard") }
            if code.contains("statsCardStyle") { offenders.append("\(path): statsCardStyle") }
            if try !ItemSourceScan.matchingLines(#"\.listCard\("#, in: code).isEmpty { offenders.append("\(path): .listCard(") }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 6. Accent shadow

    @Test func noAccentColorOrAccentShapeStyleInFeaturesOrDesignSystem() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree(), prefixes: ["Features/", "DesignSystem/"])
        where !path.hasPrefix("DesignSystem/Colors/") && path != "Features/Items/Components/ItemStatusStyle.swift" {
            // DesignSystem/Colors/ defines the accent token; ItemStatusStyle.swift maps the accent token to a Color.
            for pattern in [#"\baccentColor\b"#, #"\.accent\b"#] {
                for line in try ItemSourceScan.matchingLines(pattern, in: code) {
                    offenders.append("\(path):\(line) (\(pattern))")
                }
            }
        }
        #expect(offenders.isEmpty, "Use Color.primaryColor: \(offenders.joined(separator: "\n"))")
    }

    @Test func validationErrorTextUsesTheDestructiveToken() throws {
        let tree = try tree()
        let files = [
            "Features/Authentication/Views/RegistrationView.swift",
            "Features/Lists/Views/AddMemberView.swift",
            "Features/Lists/Views/CreateListView.swift",
            "Features/Lists/Views/EditListView.swift",
            "Features/Children/Views/AddChildView.swift"
        ]
        for file in files {
            #expect(try code(file, in: tree).contains("Color.destructiveColor"), "\(file) lacks Color.destructiveColor")
        }
    }

    // MARK: 7. State screens

    @Test func errorStateViewUsesTheDestructiveTokenAndNoRed() throws {
        let source = try code("DesignSystem/Components/ErrorStateView.swift", in: try tree())
        #expect(source.contains("Color.destructiveColor"))
        let lines = try ItemSourceScan.matchingLines(#"\.red\b"#, in: source)
        #expect(lines.isEmpty, "ErrorStateView uses .red at lines \(lines)")
    }

    @Test func stateScreensUseThePrimaryBackgroundToken() throws {
        let tree = try tree()
        for file in ["EmptyStateView.swift", "ErrorStateView.swift", "Loading/LoadingView.swift"] {
            let path = "DesignSystem/Components/\(file)"
            #expect(try code(path, in: tree).contains("Color.backgroundPrimaryColor"), "\(path) lacks Color.backgroundPrimaryColor")
        }
    }

    // MARK: 8. Skeleton and banner

    @Test func skeletonShimmerUsesThemeTokensNotGray() throws {
        let source = try code("DesignSystem/Components/Loading/SkeletonView.swift", in: try tree())
        #expect(source.contains("Color.borderColor") || source.contains("backgroundSecondaryColor"))
        let lines = try ItemSourceScan.matchingLines(#"\.(gray|black|white)\b"#, in: source)
        #expect(lines.isEmpty, "SkeletonView uses a non-theme color at lines \(lines)")
    }

    @Test func inlineErrorBannerUsesTheStyleConstantAndDestructiveToken() throws {
        let source = try code("DesignSystem/Components/InlineErrorBanner.swift", in: try tree())
        #expect(source.contains("InlineErrorBannerStyle.backgroundOpacity"))
        #expect(source.contains("Color.destructiveColor"))
        let lines = try ItemSourceScan.matchingLines(#"\.opacity\(\s*0\.12\s*\)"#, in: source)
        #expect(lines.isEmpty, "InlineErrorBanner still uses a literal 0.12 at lines \(lines)")
    }
}
