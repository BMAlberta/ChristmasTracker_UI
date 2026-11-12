//
//  ListDetailRefreshScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-F2: a narrow text scan over ListDetailView.swift.
//   - the refresh path (the body of `func refresh()`) calls refreshListDetail and refreshItems;
//   - no `.refreshable` closure calls `load()` and each one calls `refresh()`;
//   - the `.task` still calls `load()` (cache-first on open).
//
//  The rules are first proven with synthetic positive (must fire) and negative (must not fire)
//  strings, then run over the real file. Comments are stripped before matching.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum ListRefreshScan {

    /// The brace bodies of every `.refreshable` modifier in the code.
    static func refreshableBodies(in code: String) -> [String] {
        var bodies: [String] = []
        var remainder = Substring(code)
        while let range = remainder.range(of: ".refreshable") {
            let tail = String(remainder[range.lowerBound...])
            if let body = ItemSourceScan.braceBody(after: ".refreshable", in: tail) {
                bodies.append(body)
            }
            remainder = remainder[range.upperBound...]
        }
        return bodies
    }

    static func callsLoad(_ body: String) -> Bool {
        ((try? ItemSourceScan.matchingLines("\\bload\\(\\)", in: body)) ?? [-1]).isEmpty == false
    }

    static func calls(_ name: String, in body: String) -> Bool {
        ((try? ItemSourceScan.matchingLines("\\b\(name)\\(", in: body)) ?? [-1]).isEmpty == false
    }

    static func refreshBody(in code: String) -> String? {
        ItemSourceScan.braceBody(after: "func refresh()", in: code)
    }

    static func taskBody(in code: String) -> String? {
        ItemSourceScan.braceBody(after: ".task", in: code)
    }
}

@Suite("List detail refresh scan Tests")
struct ListDetailRefreshScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner proof (synthetic strings)

    @Test("a refreshable closure that calls load() is detected", arguments: [
        ".refreshable {\n    await load()\n}",
        ".refreshable { await load() }",
        ".refreshable {\n    await refresh()\n}\n.refreshable {\n    await load()\n}"
    ])
    func refreshableLoadFires(source: String) {
        let bodies = ListRefreshScan.refreshableBodies(in: code(source))
        #expect(bodies.contains(where: ListRefreshScan.callsLoad), "\(source)")
    }

    @Test("a refreshable closure that calls refresh(), reload() or a comment about load() is not flagged", arguments: [
        ".refreshable {\n    await refresh()\n}",
        ".refreshable { await reload() }",
        ".refreshable {\n    // never call load() here\n    await refresh()\n}",
        ".refreshable { await refresh() }\n.task { await load() }"
    ])
    func refreshableLoadDoesNotFire(source: String) {
        let bodies = ListRefreshScan.refreshableBodies(in: code(source))
        #expect(!bodies.isEmpty, "the scanner must find the closure: \(source)")
        #expect(!bodies.contains(where: ListRefreshScan.callsLoad), "\(source)")
    }

    @Test("the scanner finds every refreshable closure")
    func findsAllRefreshables() {
        let source = ".refreshable { await a() }\n.refreshable { await b() }"
        #expect(ListRefreshScan.refreshableBodies(in: code(source)).count == 2)
    }

    @Test("the refresh body rule needs both refreshListDetail and refreshItems")
    func refreshBodyRule() {
        let both = "private func refresh() async {\n  let e = await s.refreshListDetail(id: x)\n  await i.refreshItems()\n}"
        let onlyDetail = "private func refresh() async {\n  await s.refreshListDetail(id: x)\n}"
        let onlyItems = "private func refresh() async {\n  await i.refreshItems()\n}"
        let neither = "private func refresh() async {\n  await load()\n}"

        func hasBoth(_ source: String) -> Bool {
            guard let body = ListRefreshScan.refreshBody(in: code(source)) else { return false }
            return ListRefreshScan.calls("refreshListDetail", in: body) && ListRefreshScan.calls("refreshItems", in: body)
        }

        #expect(hasBoth(both))
        #expect(!hasBoth(onlyDetail))
        #expect(!hasBoth(onlyItems))
        #expect(!hasBoth(neither))
    }

    @Test("the task rule finds load() in the task body only")
    func taskRule() {
        let good = ".task {\n    await load()\n}\n.onDisappear { x() }"
        let bad = ".task {\n    await refresh()\n}\n.onDisappear { load() }"

        let goodBody = ListRefreshScan.taskBody(in: code(good))
        let badBody = ListRefreshScan.taskBody(in: code(bad))

        #expect(goodBody.map(ListRefreshScan.callsLoad) == true)
        #expect(badBody.map(ListRefreshScan.callsLoad) == false)
    }

    // MARK: Real source

    private func realSource(file: String = #filePath) throws -> String {
        let relative = "Features/Lists/Views/ListDetailView.swift"
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source(relative), "Could not read \(relative)")
        let stripped = ItemSourceScan.codeOnly(raw)
        #expect(!stripped.isEmpty, "\(relative) is empty after stripping comments")
        return stripped
    }

    @Test("ListDetailView has a refresh() whose body calls refreshListDetail and refreshItems")
    func realRefreshPath() throws {
        let source = try realSource()

        let body = try #require(ListRefreshScan.refreshBody(in: source), "ListDetailView.swift has no func refresh()")

        #expect(ListRefreshScan.calls("refreshListDetail", in: body), "refresh() must call refreshListDetail")
        #expect(ListRefreshScan.calls("refreshItems", in: body), "refresh() must call refreshItems")
    }

    @Test("every .refreshable closure calls refresh() and none calls load()")
    func realRefreshableClosures() throws {
        let source = try realSource()

        let bodies = ListRefreshScan.refreshableBodies(in: source)

        #expect(!bodies.isEmpty, "ListDetailView.swift has no .refreshable")
        for body in bodies {
            #expect(!ListRefreshScan.callsLoad(body), "a .refreshable closure must not call load()")
            #expect(ListRefreshScan.calls("refresh", in: body), "a .refreshable closure must call refresh()")
        }
    }

    @Test("the .task still calls load()")
    func realTaskStillLoads() throws {
        let source = try realSource()

        let body = try #require(ListRefreshScan.taskBody(in: source), "ListDetailView.swift has no .task")

        #expect(ListRefreshScan.callsLoad(body), "the .task must stay cache-first through load()")
    }
}
