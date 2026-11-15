//
//  ButtonChromeScanTests.swift
//  ChristmasTrackerTests
//
//  TH1-T5: source scans for glass chrome, the app tint and buttons. Comments are stripped before matching.
//  Scanned: Features/, DesignSystem/, App/, Navigation/, ChristmasTrackerApp.swift, ContentView.swift.
//
//  PrimaryButtonStyle adoption list: the implementer corrects it from reality; a stale entry fails.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Button chrome scans")
struct ButtonChromeScanTests {

    static let primaryButtonFiles = [
        "DesignSystem/Components/EmptyStateView.swift",
        "DesignSystem/Components/ErrorStateView.swift",
        "Features/Authentication/Views/LoginView.swift",
        "Features/Authentication/Views/RegistrationView.swift",
        "Features/Authentication/Views/BiometricSetupView.swift",
        "App/LockView.swift",
        "Features/Profile/Views/ProfileView.swift",
        "Features/Statistics/Views/BudgetCardView.swift",
        "Features/Items/Views/ItemDetailView.swift",
        "Features/Purchases/Views/ManagePurchaseView.swift",
        "Features/Purchases/Views/RecordPurchaseRecordSection.swift",
        "Features/Purchases/Views/RecordPurchaseExpiredNotice.swift",
        "Features/Purchases/Views/BudgetWarningPanel.swift"
    ]

    private static let scopedPrefixes = ["Features/", "DesignSystem/", "App/", "Navigation/"]
    private static let rootFiles = ["ChristmasTrackerApp.swift", "ContentView.swift"]
    private static let appFile = "ChristmasTrackerApp.swift"

    private func tree(_ file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func sources(in tree: ItemSourceTree) throws -> [(path: String, code: String)] {
        var result: [(String, String)] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard Self.scopedPrefixes.contains(where: { relative.hasPrefix($0) }) || Self.rootFiles.contains(relative) else { continue }
            result.append((relative, ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        return result
    }

    private func code(_ relative: String, in tree: ItemSourceTree) throws -> String {
        let text = try #require(tree.source(relative), "\(relative) is missing")
        return ItemSourceScan.codeOnly(text)
    }

    private func count(of needle: String, in code: String) -> Int {
        code.components(separatedBy: needle).count - 1
    }

    // MARK: 1. No glass and no appearance proxies

    @Test func noGlassOrAppearanceApiAnywhere() throws {
        let banned = [
            "glassEffect", "GlassEffectContainer", ".toolbarBackground(", ".toolbarColorScheme(",
            "UINavigationBarAppearance", "UITabBarAppearance", "UIToolbarAppearance", "UIBarButtonItemAppearance",
            ".appearance()", ".appearance(whenContainedInInstancesOf", "UIAppearance"
        ]
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) {
            for token in banned where code.contains(token) {
                offenders.append("\(path): \(token)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 2. The app tint

    @Test func appTintIsSetExactlyOnceInTheAppFile() throws {
        var total = 0
        var places: [String] = []
        for (path, code) in try sources(in: try tree()) {
            let n = count(of: ".tint(Color.primaryColor)", in: code) + count(of: ".tint(.primaryColor)", in: code)
            if n > 0 { places.append("\(path) x\(n)") }
            total += n
        }
        #expect(total == 1, "expected exactly one app tint, found \(total): \(places.joined(separator: ", "))")
        #expect(places.count == 1 && places.first?.hasPrefix(Self.appFile) == true, "the tint must be in \(Self.appFile): \(places)")
    }

    @Test func appTintIsAppliedInsideAppContent() throws {
        let code = try code(Self.appFile, in: try tree())
        let body = try #require(ItemSourceScan.braceBody(after: "private var appContent", in: code), "appContent is missing")
        #expect(body.contains(".tint(Color.primaryColor)") || body.contains(".tint(.primaryColor)"))
    }

    @Test func tabBarViewHasNoTint() throws {
        let code = try code("Navigation/TabBarView.swift", in: try tree())
        #expect(!code.contains(".tint("))
        #expect(count(of: ".tabBarMinimizeBehavior(.onScrollDown)", in: code) == 1)
    }

    // MARK: 3. Primary buttons

    @Test func borderedProminentIsGone() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where code.contains("borderedProminent") {
            offenders.append(path)
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test func primaryButtonFilesUsePrimaryButtonStyle() throws {
        let tree = try tree()
        var missing: [String] = []
        for file in Self.primaryButtonFiles {
            if !(try code(file, in: tree).contains(".buttonStyle(PrimaryButtonStyle())")) { missing.append(file) }
        }
        #expect(missing.isEmpty, "Not using PrimaryButtonStyle(): \(missing.joined(separator: "\n"))")
    }

    @Test func styleFileDefinesTheStyleFromThemeTokens() throws {
        let source = try code("DesignSystem/Components/AppButtonStyles.swift", in: try tree())
        #expect(source.contains("struct PrimaryButtonStyle: ButtonStyle"))
        #expect(source.contains("Color(label:"))
        #expect(source.contains("PrimaryButtonLabelTable"))
        #expect(source.contains("Capsule"))
        #expect(!source.contains("borderedProminent"))
        #expect(try ItemSourceScan.matchingLines(#"\.white\b"#, in: source).isEmpty)
    }

    // MARK: 4. White

    @Test func whiteAppearsOnlyInTheStyleLayerAndTheTokenData() throws {
        let allowed: Set<String> = [
            "Features/Items/Components/ItemStatusStyle.swift",
            "DesignSystem/Colors/ThemeTokenTable.swift"
        ]
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where !allowed.contains(path) {
            for line in try ItemSourceScan.matchingLines(#"\.white\b"#, in: code) {
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 5. No filled destructive button

    @Test func noButtonWithTheDestructiveRoleIsFilledOrPrimary() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) {
            var searchStart = code.startIndex
            while let hit = code.range(of: "role: .destructive", range: searchStart..<code.endIndex) {
                let tail = code[hit.lowerBound...]
                let nextButton = tail.dropFirst().range(of: "Button(")?.lowerBound ?? tail.endIndex
                let segment = String(tail[..<nextButton].prefix(1500))
                if segment.contains(".buttonStyle(PrimaryButtonStyle())") {
                    offenders.append("\(path): destructive button uses PrimaryButtonStyle")
                }
                if segment.contains(".buttonStyle(.borderedProminent)") {
                    offenders.append("\(path): destructive button uses borderedProminent")
                }
                if segment.contains(".background(Color.destructiveColor") {
                    offenders.append("\(path): destructive button has a filled background")
                }
                searchStart = hit.upperBound
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test func destructiveColorIsNeverAButtonBackgroundFill() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) {
            // `.opacity` derived tints (the inline banner) are not a solid fill.
            for line in try ItemSourceScan.matchingLines(#"\.background\(\s*(Color)?\.destructiveColor(?!\.opacity)"#, in: code) {
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test func archiveListIsBorderedWithDestructiveTint() throws {
        let code = try code("Features/Lists/Views/ListDetailView.swift", in: try tree())
        let hit = try #require(code.range(of: "Button(role: .destructive)"), "Archive List button not found")
        let tail = code[hit.lowerBound...]
        let end = tail.dropFirst().range(of: "Button(")?.lowerBound ?? tail.endIndex
        let segment = String(tail[..<end].prefix(1500))
        #expect(segment.contains(".buttonStyle(.bordered)"), "Archive List must be .bordered")
        #expect(segment.contains("destructiveTint()"), "Archive List must use destructiveTint()")
        #expect(!segment.contains("Color.destructiveColor"), "Archive List must not paint the destructive color itself")
    }

    // MARK: 6. Per-control tints

    @Test func remainingTintsAreAllowedTokens() throws {
        let allowedPrefixes = [
            "Color.destructiveColor", "Color.textMutedColor", "BudgetLevelColors.",
            "Color.backgroundPrimaryColor", "Color.surfaceColor",
            // PrimaryButtonStyle gives a ProgressView in its label the label color.
            "labelColor)"
        ]
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) where path != Self.appFile {
            let lines = code.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                guard let range = line.range(of: ".tint(") else { continue }
                let argument = String(line[range.upperBound...])
                if !allowedPrefixes.contains(where: { argument.hasPrefix($0) }) {
                    offenders.append("\(path):\(index + 1) \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test func noWhiteTintAnywhere() throws {
        var offenders: [String] = []
        for (path, code) in try sources(in: try tree()) {
            for pattern in [#"\.tint\(\s*\.white"#, #"\.tint\(\s*Color\.white"#] {
                for line in try ItemSourceScan.matchingLines(pattern, in: code) {
                    offenders.append("\(path):\(line)")
                }
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 7. Corner radius literals

    @Test func buttonsInTheThreeFilesHaveNoCornerRadiusLiteral() throws {
        let tree = try tree()
        let files = [
            "Features/Profile/Views/ProfileView.swift",
            "DesignSystem/Components/EmptyStateView.swift",
            "DesignSystem/Components/ErrorStateView.swift"
        ]
        for file in files {
            let source = try code(file, in: tree)
            #expect(!source.contains(".cornerRadius("), "\(file) uses .cornerRadius(")
            let lines = try ItemSourceScan.matchingLines(#"rect\(\s*cornerRadius:\s*12\s*\)"#, in: source)
            #expect(lines.isEmpty, "\(file) has rect(cornerRadius: 12) at lines \(lines)")
        }
    }
}
