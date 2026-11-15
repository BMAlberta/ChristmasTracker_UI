//
//  TabBarMinimizeScanTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B3 (Rule 4): the tab bar minimizes on scroll down. `.tabBarMinimizeBehavior(.onScrollDown)`
//  is set exactly once, on the TabView in TabBarView.swift, and nowhere else.
//  Needs the checkout on disk, which scripts/test.sh has.
//
//  NOTE ON TAB ROOTS (required by the story): the three tab roots are vertical scroll views, so the
//  minimize behavior has a scroll to react to: DashboardView (List), StatsView (ScrollView) and
//  ProfileView (ScrollView). The last test guards that.
//

import Foundation
import Testing

@Suite("Tab bar minimize scan Tests")
struct TabBarMinimizeScanTests {

    private static let tabBar = "Navigation/TabBarView.swift"
    private static let modifier = ".tabBarMinimizeBehavior(.onScrollDown)"

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func code(_ relative: String, in tree: ItemSourceTree) throws -> String {
        let source = try #require(tree.source(relative), "Could not read \(relative)")
        return ItemSourceScan.codeOnly(source)
    }

    @Test("OLD: no minimize behavior was set; TabBarView sets .onScrollDown exactly once")
    func setExactlyOnce() throws {
        let code = try code(Self.tabBar, in: try tree())
        let count = code.components(separatedBy: Self.modifier).count - 1
        #expect(count == 1, "expected \(Self.modifier) exactly once in TabBarView.swift, found \(count)")
    }

    @Test("OLD: no minimize behavior was set; the modifier is chained on the TabView, after its block closes")
    func chainedOnTheTabView() throws {
        let code = try code(Self.tabBar, in: try tree())
        let body = try #require(
            ItemSourceScan.braceBody(after: "TabView(selection:", in: code),
            "Could not find the TabView(selection:) block"
        )
        #expect(!body.contains("tabBarMinimizeBehavior"), "the modifier must follow the TabView block, not sit inside it")
        let headerRange = try #require(code.range(of: "TabView(selection:"))
        let afterHeader = code[headerRange.upperBound...]
        let open = try #require(afterHeader.range(of: body))
        let tail = afterHeader[open.upperBound...]
        let modifierRange = try #require(tail.range(of: Self.modifier), "the modifier is not after the TabView block")
        let between = tail[..<modifierRange.lowerBound]
        // Only other modifiers (like .tint) may sit between the closing brace and the minimize modifier.
        #expect(!between.contains("TabView"), "the modifier must be chained on this TabView")
        #expect(!between.contains("{") || between.contains(".tint"), "unexpected block between the TabView and the modifier")
    }

    @Test("OLD: no minimize behavior was set; no other app source file mentions tabBarMinimizeBehavior")
    func nowhereElse() throws {
        let tree = try tree()
        var offenders: [String] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative != Self.tabBar else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            if ItemSourceScan.codeOnly(source).contains("tabBarMinimizeBehavior") {
                offenders.append(relative)
            }
        }
        #expect(!tree.all.isEmpty)
        #expect(offenders.isEmpty, "tabBarMinimizeBehavior found outside TabBarView.swift: \(offenders.joined(separator: ", "))")
    }

    @Test("OLD: no minimize behavior was set; the tint and the three tabs are unchanged")
    func tabsUnchanged() throws {
        let code = try code(Self.tabBar, in: try tree())
        #expect(!code.contains(".tint("), "the app tint now lives in ChristmasTrackerApp, not the tab bar")
        for tag in [".tag(TabSelection.dashboard)", ".tag(TabSelection.stats)", ".tag(TabSelection.profile)"] {
            #expect(code.contains(tag), "missing tab: \(tag)")
        }
        #expect(code.components(separatedBy: ".tag(").count - 1 == 3, "the number of tabs changed")
    }

    @Test("OLD: no minimize behavior was set; each tab root is a vertical ScrollView or List")
    func tabRootsScroll() throws {
        let tree = try tree()
        let roots = [
            "Features/Dashboard/Views/DashboardView.swift",
            "Features/Statistics/Views/StatsView.swift",
            "Features/Profile/Views/ProfileView.swift"
        ]
        for relative in roots {
            let code = try code(relative, in: tree)
            let hasScroll = try !ItemSourceScan.matchingLines(#"\bScrollView\s*(\(|\{)"#, in: code).isEmpty
            let hasList = try !ItemSourceScan.matchingLines(#"\bList\s*(\(|\{)"#, in: code).isEmpty
            #expect(hasScroll || hasList, "\(relative) has no ScrollView or List")
            #expect(!code.contains("ScrollView(.horizontal"), "\(relative) root must not be a horizontal-only scroll")
        }
    }
}
