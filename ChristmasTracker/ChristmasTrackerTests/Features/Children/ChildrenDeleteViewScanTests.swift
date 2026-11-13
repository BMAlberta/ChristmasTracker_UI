//
//  ChildrenDeleteViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D3: text-scan evidence for the Children delete UI (UI rules for new code).
//
//  Scope (found by scanning folders, comments stripped first):
//   - Features/Children/Views         (confirmation placement, destructive tint, tokens, flow binding)
//   - Features/Children/Views, ViewState, Services  (no personal data in logs or identifiers)
//
//  The source root is found from #filePath, like MembersChildrenViewScanTests.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Children delete view scan Tests")
struct ChildrenDeleteViewScanTests {

    // MARK: - Patterns

    private static let dialogPattern = #"\.confirmationDialog\s*\("#
    private static let containerPatterns: [(name: String, pattern: String)] = [
        ("List", #"\bList\s*(?:\{|\()"#),
        ("ScrollView", #"\bScrollView\b"#),
        ("Form", #"\bForm\s*(?:\{|\()"#),
        ("NavigationStack", #"\bNavigationStack\b"#)
    ]
    private static let loggingCallPattern =
        #"\b(?:Log(?:Debug|Info|Warning|Error|Critical)|print|debugPrint|NSLog|os_log|Logger)\s*\([^\n]*\\\("#
    private static let identifierCallPattern = #"accessibilityIdentifier\("#
    private static let identifierLiteralPattern = #"accessibilityIdentifier\(\s*"[^"\\]*"\s*\)"#
    private static let runCallPattern = #"\.run\s*\("#
    private static let stateAttributePattern = #"@State\b"#
    private static let oldConfirmationStatePattern = #"\b(?:pendingPlan|showsConfirmation)\b"#
    private static let deferPattern = #"\bdefer\b"#
    private static let deletingIdAssignmentPattern = #"\bdeletingChildId\s*=(?!=)"#
    private static let sleepPattern = #"\bTask\s*\.\s*sleep\b"#
    private static let yieldPattern = #"\bTask\s*\.\s*yield\b"#
    private static let queuePattern = #"\bDispatch"# + #"Queue\b"#
    private static let presentationStatePattern =
        #"@State\s+(?:private\s+)?var\s+\w+\s*(?::\s*ChildDeletionPresentation\b|=\s*ChildDeletionPresentation\b)"#
    private static let requestDeleteCallPattern = #"\.requestDelete\s*\(\s*childId\s*:"#
    private static let retryFunctionPattern = #"func\s+retry\w*"#
    private static let structPattern = #"(?m)^\s*(?:(?:private|fileprivate|public)\s+)?(?:final\s+)?struct\s+(\w+)"#

    // MARK: - Source discovery

    private static func appSourceRoot(from file: URL) -> URL? {
        var directory = file.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let root = directory.deletingLastPathComponent()
                    .appendingPathComponent("ChristmasTracker", isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return root
                }
                return nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    private static func swiftFiles(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }

    private static func codeOnly(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        var blockDepth = 0
        while index < source.endIndex {
            let next = source.index(after: index)
            let pair = next < source.endIndex ? String(source[index...next]) : ""
            if pair == "/*" {
                blockDepth += 1
                index = source.index(after: next)
            } else if pair == "*/" && blockDepth > 0 {
                blockDepth -= 1
                index = source.index(after: next)
            } else if blockDepth > 0 {
                if source[index] == "\n" { result.append("\n") }
                index = next
            } else if pair == "//" {
                while index < source.endIndex && source[index] != "\n" {
                    index = source.index(after: index)
                }
            } else {
                result.append(source[index])
                index = next
            }
        }
        return result
    }

    private static func matches(_ pattern: String, in code: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern)
        let whole = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: whole).map { match in
            code.prefix(match.range.location).filter { $0 == "\n" }.count + 1
        }
    }

    /// The code of every struct declared in `code`, as (name, body) pairs: from its declaration to
    /// the next struct declaration or `#Preview`, whichever comes first.
    private static func structSegments(in code: String) throws -> [(name: String, body: String)] {
        let regex = try NSRegularExpression(pattern: structPattern)
        let whole = NSRange(code.startIndex..., in: code)
        let found = regex.matches(in: code, range: whole)
        var segments: [(name: String, body: String)] = []
        for (position, match) in found.enumerated() {
            guard let nameRange = Range(match.range(at: 1), in: code),
                  let start = Range(match.range, in: code)?.lowerBound else { continue }
            var end = code.endIndex
            if position + 1 < found.count, let nextStart = Range(found[position + 1].range, in: code)?.lowerBound {
                end = nextStart
            }
            var body = String(code[start..<end])
            if let preview = body.range(of: "#Preview") {
                body = String(body[..<preview.lowerBound])
            }
            segments.append((String(code[nameRange]), body))
        }
        return segments
    }

    private struct Scope {
        let root: URL
        let views: [URL]
        let viewState: [URL]
        let services: [URL]

        var personalDataScope: [URL] { views + viewState + services }

        func relative(_ url: URL) -> String {
            let rootPath = root.standardizedFileURL.path + "/"
            let path = url.standardizedFileURL.path
            return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
        }
    }

    private func makeSUT(file: String = #filePath) throws -> Scope {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        func folder(_ relative: String) -> [URL] {
            Self.swiftFiles(under: root.appendingPathComponent(relative, isDirectory: true))
        }
        let scope = Scope(
            root: root,
            views: folder("Features/Children/Views"),
            viewState: folder("Features/Children/ViewState"),
            services: folder("Features/Children/Services")
        )
        try #require(!scope.views.isEmpty, "Features/Children/Views has no .swift files")
        return scope
    }

    private func code(_ url: URL) throws -> String {
        Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func viewsCode(_ scope: Scope) throws -> String {
        try scope.views.map { try code($0) }.joined(separator: "\n")
    }

    // MARK: - Scanner self-checks

    @Test("The struct segmenter separates structs and stops at #Preview")
    func segmenterIsExact() throws {
        let sample = """
        struct Screen: View {
            var body: some View { List { Text("x") } }
        }
        private struct Row: View {
            var body: some View { Text("y").confirmationDialog("t", isPresented: $p) { } }
        }
        #Preview { NavigationStack { Screen() } }
        """
        let segments = try Self.structSegments(in: sample)
        #expect(segments.map(\.name) == ["Screen", "Row"])
        #expect(segments[0].body.contains("List {"))
        #expect(!segments[1].body.contains("List {"))
        #expect(!segments[1].body.contains("NavigationStack"))
        #expect(segments[1].body.contains(".confirmationDialog("))
    }

    @Test("The logging and identifier patterns match interpolation only")
    func patternsAreExact() throws {
        let bad = [#"LogInfo("removed \(child.id)")"#, #"print("name \(name)")"#]
        let good = [#"LogInfo("removed child")"#, #"print("done")"#]
        for text in bad { #expect(try !Self.matches(Self.loggingCallPattern, in: text).isEmpty, "Expected: \(text)") }
        for text in good { #expect(try Self.matches(Self.loggingCallPattern, in: text).isEmpty, "Unexpected: \(text)") }
        #expect(try !Self.matches(Self.identifierLiteralPattern, in: #".accessibilityIdentifier("children.addButton")"#).isEmpty)
        #expect(try Self.matches(Self.identifierLiteralPattern, in: #".accessibilityIdentifier("row-\(id)")"#).isEmpty)
        #expect(try Self.matches(Self.identifierLiteralPattern, in: #".accessibilityIdentifier(prefix + "x")"#).isEmpty)
    }

    // MARK: - (a) one dialog, attached to a row

    @Test("(a) Exactly one confirmationDialog exists in the Children views")
    func exactlyOneDialog() throws {
        let scope = try makeSUT()
        var total = 0
        for url in scope.views {
            total += try Self.matches(Self.dialogPattern, in: try code(url)).count
        }
        #expect(total == 1, "Expected exactly one .confirmationDialog in Features/Children/Views, found \(total)")
    }

    @Test("(a) The confirmationDialog lives in a row wrapper, not in a struct with a List, ScrollView, Form or NavigationStack")
    func dialogIsOnTheRow() throws {
        let scope = try makeSUT()
        var hosts: [String] = []
        for url in scope.views {
            for segment in try Self.structSegments(in: try code(url))
            where !(try Self.matches(Self.dialogPattern, in: segment.body)).isEmpty {
                hosts.append(segment.name)
                #expect(segment.name != "ChildrenView", "The dialog must not be attached to the screen struct")
                for container in Self.containerPatterns {
                    #expect(try Self.matches(container.pattern, in: segment.body).isEmpty,
                            "The dialog host \(segment.name) in \(scope.relative(url)) also contains \(container.name)")
                }
            }
        }
        #expect(hosts.count == 1, "The dialog must be found inside exactly one struct, found \(hosts)")
    }

    // MARK: - (b) old alert and screen-level state gone

    @Test("(b) No alert and no childToDelete remain in the Children views")
    func oldDeleteUiIsGone() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try Self.matches(#"\.alert\s*\("#, in: text).isEmpty, "An .alert remains in the Children views")
        #expect(try Self.matches(#"\bchildToDelete\b"#, in: text).isEmpty, "childToDelete remains")
        #expect(try Self.matches(#"Couldn't remove child"#, in: text).isEmpty, "The old alert title remains")
        #expect(try Self.matches(#"\bactionErrorMessage\b"#, in: text).isEmpty, "The old alert state remains")
    }

    // MARK: - (c) destructive actions are tinted

    @Test("(c) Every file with role: .destructive also uses Color.destructiveColor")
    func destructiveIsTinted() throws {
        let scope = try makeSUT()
        var destructiveFiles = 0
        for url in scope.views {
            let text = try code(url)
            guard !(try Self.matches(#"role:\s*\.destructive"#, in: text)).isEmpty else { continue }
            destructiveFiles += 1
            #expect(text.contains("Color.destructiveColor"),
                    "\(scope.relative(url)) has role: .destructive but no Color.destructiveColor tint")
        }
        #expect(destructiveFiles > 0, "No destructive action found in the Children views")
    }

    // MARK: - (d) tokens only

    @Test("(d) ChildrenView.swift and the dialog host file use design tokens only")
    func tokensOnly() throws {
        let scope = try makeSUT()
        var urls = scope.views.filter { $0.lastPathComponent == "ChildrenView.swift" }
        for url in scope.views where !(try Self.matches(Self.dialogPattern, in: try code(url))).isEmpty {
            if !urls.contains(url) { urls.append(url) }
        }
        #expect(!urls.isEmpty)
        var found: [String] = []
        for url in urls {
            let text = try code(url)
            for entry in ListViewScanTests.tokenPatterns {
                for line in try Self.matches(entry.pattern, in: text) {
                    found.append("\(scope.relative(url)):\(line) \(entry.name)")
                }
            }
        }
        #expect(found.isEmpty, "Raw styling found:\n\(found.joined(separator: "\n"))")
    }

    // MARK: - (e) no personal data in logs or identifiers

    @Test("(e) No log or print call in Children views, view state or services interpolates a value")
    func noInterpolationInLogs() throws {
        let scope = try makeSUT()
        var found: [String] = []
        for url in scope.personalDataScope {
            for line in try Self.matches(Self.loggingCallPattern, in: try code(url)) {
                found.append("\(scope.relative(url)):\(line)")
            }
        }
        #expect(found.isEmpty, "Interpolation inside a log call:\n\(found.joined(separator: "\n"))")
    }

    @Test("(e) Every accessibility identifier in the Children files is a plain string literal")
    func identifiersAreLiterals() throws {
        let scope = try makeSUT()
        for url in scope.personalDataScope {
            let text = try code(url)
            let calls = try Self.matches(Self.identifierCallPattern, in: text).count
            let literals = try Self.matches(Self.identifierLiteralPattern, in: text).count
            #expect(calls == literals, "\(scope.relative(url)) has an accessibilityIdentifier that is not a plain literal")
        }
    }

    // MARK: - (f) the view goes through the flow

    @Test("(f) The Children views use ChildDeletionFlow and never call deleteChild directly")
    func viewUsesTheFlow() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(text.contains("ChildDeletionFlow"), "The Children views must use ChildDeletionFlow")
        #expect(try Self.matches(#"\.deleteChild\s*\("#, in: text).isEmpty,
                "A Children view calls deleteChild directly; go through ChildDeletionFlow")
        #expect(try !Self.matches(#"\.plan\s*\(\s*childId\s*:"#, in: text).isEmpty,
                "The row must request ChildDeletionFlow.plan(childId:) first")
        #expect(try !Self.matches(#"\.execute\s*\(\s*childId\s*:"#, in: text).isEmpty,
                "The row must call ChildDeletionFlow.execute after the confirmation")
        #expect(try Self.matches(Self.runCallPattern, in: text).isEmpty,
                "Try Again must run plan then execute, not ChildDeletionFlow.run")
    }

    @Test("(f) The Children views build the confirmation and the banner from the pure states")
    func viewUsesThePureStates() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try !Self.matches(#"deleteConfirmation\s*\(\s*for:[^)]*plan:"#, in: text).isEmpty,
                "The dialog must come from ChildrenState.deleteConfirmation(for:plan:)")
        #expect(text.contains("ChildrenState.banner(for"), "The banner must come from ChildrenState.banner(for:)")
        #expect(text.contains("InlineErrorBanner"), "Errors must use InlineErrorBanner")
        #expect(text.contains("deleteControlsEnabled"), "Controls must be gated by ChildrenState.deleteControlsEnabled")
        #expect(text.contains("progressAnnouncement"), "VoiceOver must announce progress")
        #expect(text.contains("resultAnnouncement"), "VoiceOver must announce the result")
    }

    // MARK: - Fix pass F1: the confirmation state lives above the rows

    /// The first `{ ... }` block (balanced) that starts after the first match of `pattern`.
    private static func block(afterMatchOf pattern: String, in code: String) throws -> String? {
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)),
              let matchRange = Range(match.range, in: code),
              let open = code[matchRange.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" {
                depth += 1
            } else if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    private func childRowBody(_ scope: Scope) throws -> String {
        var bodies: [String] = []
        for url in scope.views {
            for segment in try Self.structSegments(in: try code(url)) where segment.name == "ChildRow" {
                bodies.append(segment.body)
            }
        }
        #expect(bodies.count == 1, "Expected exactly one ChildRow struct in the Children views, found \(bodies.count)")
        return try #require(bodies.first)
    }

    @Test("(g) The F1 scanner helpers are exact")
    func f1PatternsAreExact() throws {
        #expect(try !Self.matches(Self.stateAttributePattern, in: "@State private var x = 1").isEmpty)
        #expect(try Self.matches(Self.stateAttributePattern, in: "@StateObject var x").isEmpty)
        #expect(try Self.matches(Self.stateAttributePattern, in: "let isStateful = 1").isEmpty)
        #expect(try !Self.matches(Self.oldConfirmationStatePattern, in: "@State private var pendingPlan: P?").isEmpty)
        #expect(try !Self.matches(Self.oldConfirmationStatePattern, in: "showsConfirmation = true").isEmpty)
        #expect(try Self.matches(Self.oldConfirmationStatePattern, in: "isConfirmationPresented").isEmpty)
        #expect(try !Self.matches(Self.deferPattern, in: "defer { x = nil }").isEmpty)
        #expect(try Self.matches(Self.deferPattern, in: "let deferred = 1").isEmpty)
        #expect(try !Self.matches(Self.deletingIdAssignmentPattern, in: "deletingChildId = nil").isEmpty)
        #expect(try !Self.matches(Self.deletingIdAssignmentPattern, in: "deletingChildId = childId").isEmpty)
        #expect(try Self.matches(Self.deletingIdAssignmentPattern, in: "if deletingChildId == nil { }").isEmpty)
        #expect(try Self.matches(Self.deletingIdAssignmentPattern, in: "let deletingChildId: String? = deletion.deletingChildId").isEmpty)
        #expect(try !Self.matches(Self.sleepPattern, in: "try await Task.sleep(for: .seconds(1))").isEmpty)
        #expect(try !Self.matches(Self.yieldPattern, in: "await Task.yield()").isEmpty)
        #expect(try !Self.matches(Self.queuePattern, in: "Dispatch" + "Queue.main.async { }").isEmpty)
        #expect(try Self.matches(Self.sleepPattern, in: "let sleeper = 1").isEmpty)
        #expect(try !Self.matches(Self.runCallPattern, in: "await flow.run(childId: id)").isEmpty)
        #expect(try Self.matches(Self.runCallPattern, in: "await flow.execute(childId: id, plan: p)").isEmpty)
        #expect(try !Self.matches(Self.presentationStatePattern,
                                  in: "@State private var deletion = ChildDeletionPresentation.idle").isEmpty)
        #expect(try !Self.matches(Self.presentationStatePattern,
                                  in: "@State private var deletion: ChildDeletionPresentation = .idle").isEmpty)
        #expect(try Self.matches(Self.presentationStatePattern, in: "@State private var deletion: String?").isEmpty)
        #expect(try Self.matches(Self.presentationStatePattern, in: "@State private var deletion = .idle").isEmpty)
        #expect(try !Self.matches(Self.requestDeleteCallPattern, in: "deletion = deletion.requestDelete(childId: id)").isEmpty)
        #expect(try Self.matches(Self.requestDeleteCallPattern, in: "onRequestDelete()").isEmpty)
        #expect(try !Self.matches(Self.retryFunctionPattern, in: "private func retryDeletion() {").isEmpty)
    }

    @Test("(g) The block extractor returns the balanced block after a marker")
    func blockExtractorIsExact() throws {
        let sample = #"a.swipeActions(edge: .trailing) { Button { inner() } label: { Text("x") } } b.other { later() }"#
        let found = try #require(try Self.block(afterMatchOf: #"\.swipeActions\s*\("#, in: sample))
        #expect(found.contains("inner()"))
        #expect(!found.contains("later()"))
        #expect(try Self.block(afterMatchOf: #"\.missing\s*\("#, in: sample) == nil)
        #expect(try Self.block(afterMatchOf: #"\.swipeActions\s*\("#, in: "a.swipeActions(x) { unbalanced") == nil)
    }

    @Test("(g) ChildRow has no @State at all")
    func childRowHasNoState() throws {
        let scope = try makeSUT()
        let row = try childRowBody(scope)
        #expect(try Self.matches(Self.stateAttributePattern, in: row).isEmpty,
                "ChildRow must not own @State; the presentation lives on ChildrenView")
    }

    @Test("(g) No pendingPlan or showsConfirmation remains anywhere in the Children views")
    func oldConfirmationStateIsGone() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try Self.matches(Self.oldConfirmationStatePattern, in: text).isEmpty,
                "pendingPlan or showsConfirmation remains in the Children views")
    }

    @Test("(g) ChildrenView owns the presentation as @State of type ChildDeletionPresentation")
    func screenOwnsThePresentation() throws {
        let scope = try makeSUT()
        let screenFiles = scope.views.filter { $0.lastPathComponent == "ChildrenView.swift" }
        #expect(screenFiles.count == 1)
        let text = try screenFiles.map { try code($0) }.joined(separator: "\n")
        #expect(try Self.matches(Self.presentationStatePattern, in: text).count == 1,
                "ChildrenView.swift must declare exactly one @State of type ChildDeletionPresentation")
        let row = try childRowBody(scope)
        #expect(try Self.matches(Self.presentationStatePattern, in: row).isEmpty)
    }

    @Test("(g) The confirmationDialog is inside the ChildRow struct")
    func dialogIsInChildRow() throws {
        let scope = try makeSUT()
        let row = try childRowBody(scope)
        #expect(try Self.matches(Self.dialogPattern, in: row).count == 1,
                "The single confirmationDialog must be inside ChildRow")
    }

    @Test("(g) No defer and no deletingChildId assignment remain in the Children views")
    func noDeferAndNoFlagAssignment() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try Self.matches(Self.deferPattern, in: text).isEmpty, "A defer remains in the Children views")
        #expect(try Self.matches(Self.deletingIdAssignmentPattern, in: text).isEmpty,
                "A deletingChildId assignment remains in the Children views")
    }

    @Test("(g) No Task.sleep, Task.yield or dispatch queue in the Children views")
    func noTimingTricks() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try Self.matches(Self.sleepPattern, in: text).isEmpty, "Task.sleep in the Children views")
        #expect(try Self.matches(Self.yieldPattern, in: text).isEmpty, "Task.yield in the Children views")
        #expect(try Self.matches(Self.queuePattern, in: text).isEmpty, "A dispatch queue in the Children views")
    }

    @Test("(g) The views drive the presentation through its transitions and gate controls by it")
    func viewsUseTheTransitions() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        for transition in [#"\.planReady\s*\("#, #"\.planFailed\s*\("#, #"\.cancelConfirmation\s*\("#,
                           #"\.confirm\s*\(\s*childId\s*:"#, #"\.executionFinished\s*\("#,
                           #"\.childrenChanged\s*\(\s*existingIds\s*:"#, #"\.reset\s*\(\s*\)"#] {
            #expect(try !Self.matches(transition, in: text).isEmpty, "The views never call \(transition)")
        }
        #expect(try !Self.matches(#"deleteControlsEnabled\s*\([^)]*deletion\s*:"#, in: text).isEmpty,
                "Controls must be gated by deleteControlsEnabled(isMutating:deletion:)")
        #expect(text.contains("planningAnnouncement"), "VoiceOver must announce the plan step")
        #expect(text.contains("retryAnnouncement"), "Try Again must announce from the recomputed plan")
    }

    @Test("(g) requestDelete goes through the presentation, from the row handler and from Try Again")
    func requestDeleteGoesThroughThePresentation() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        #expect(try Self.matches(Self.requestDeleteCallPattern, in: text).count >= 2,
                "Both the row request and Try Again must call the presentation's requestDelete(childId:)")
        let retry = try #require(try Self.block(afterMatchOf: Self.retryFunctionPattern, in: text),
                                 "No retry function found (expected func retry...)")
        #expect(try !Self.matches(Self.requestDeleteCallPattern, in: retry).isEmpty,
                "Try Again must start with the presentation's requestDelete")
        #expect(try !Self.matches(#"\.plan\s*\(\s*childId\s*:"#, in: retry).isEmpty, "Try Again must plan first")
        #expect(try !Self.matches(#"\.execute\s*\(\s*childId\s*:"#, in: retry).isEmpty, "Try Again must then execute")
        #expect(try !Self.matches(#"requiresConfirmation\s*:\s*false"#, in: retry).isEmpty,
                "Try Again continues without a new dialog")
        #expect(retry.contains("retryAnnouncement"), "Try Again announces from the recomputed plan")
        #expect(try Self.matches(Self.runCallPattern, in: retry).isEmpty)
        #expect(try !Self.matches(#"onTryAgain\s*:[^\n]*\bretry"#, in: text).isEmpty,
                "The banner's Try Again must call the retry function")
    }

    /// Every function body (balanced braces after `func name`) that contains `marker`.
    private static func functionBodies(containing marker: String, in code: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #"\bfunc\s+\w+"#)
        var found: [String] = []
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let range = Range(match.range, in: code),
                  let open = code[range.upperBound...].firstIndex(of: "{") else { continue }
            var depth = 0
            var index = open
            while index < code.endIndex {
                if code[index] == "{" {
                    depth += 1
                } else if code[index] == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
                index = code.index(after: index)
            }
            guard depth == 0, index < code.endIndex else { continue }
            let body = String(code[open...index])
            if try !matches(marker, in: body).isEmpty { found.append(body) }
        }
        return found
    }

    private static let planReadyPattern = #"\.planReady\s*\("#
    private static let childrenChangedPattern = #"\.childrenChanged\s*\(\s*existingIds\s*:"#

    /// True when `childrenChanged(existingIds:` appears after the first `.planReady(` in `body`.
    private static func reevaluatesAfterPlanReady(_ body: String) throws -> Bool {
        guard let planLine = try matches(planReadyPattern, in: body).first else { return false }
        return try matches(childrenChangedPattern, in: body).contains { $0 >= planLine }
    }

    @Test("(g) The F1 re-evaluation scanner helpers are exact")
    func reevaluationHelpersAreExact() throws {
        let good = "func apply() {\n  let t = d.planReady(childId: id, plan: p, requiresConfirmation: true)\n  d = t.presentation.childrenChanged(existingIds: ids)\n}\nfunc other() { x() }"
        let bad = "func apply() {\n  d = d.childrenChanged(existingIds: ids)\n  let t = d.planReady(childId: id, plan: p, requiresConfirmation: true)\n}"
        let missing = "func apply() {\n  let t = d.planReady(childId: id, plan: p, requiresConfirmation: true)\n}\nfunc elsewhere() { d.childrenChanged(existingIds: ids) }"
        let goodBodies = try Self.functionBodies(containing: Self.planReadyPattern, in: good)
        #expect(goodBodies.count == 1)
        #expect(try Self.reevaluatesAfterPlanReady(try #require(goodBodies.first)))
        #expect(try !Self.reevaluatesAfterPlanReady(try #require(Self.functionBodies(containing: Self.planReadyPattern, in: bad).first)))
        #expect(try !Self.reevaluatesAfterPlanReady(try #require(Self.functionBodies(containing: Self.planReadyPattern, in: missing).first)))
        #expect(try Self.functionBodies(containing: Self.planReadyPattern, in: "func a() { }").isEmpty)
    }

    @Test("(g) Every function that applies planReady re-evaluates childrenChanged(existingIds:) after it")
    func planReadyIsFollowedByChildrenChanged() throws {
        let scope = try makeSUT()
        let text = try viewsCode(scope)
        let bodies = try Self.functionBodies(containing: Self.planReadyPattern, in: text)
        #expect(!bodies.isEmpty, "No function applying .planReady( found in the Children views")
        for body in bodies {
            #expect(try Self.reevaluatesAfterPlanReady(body),
                    "A function applying .planReady( must call .childrenChanged(existingIds:) afterwards, with the current child ids")
        }
    }

    @Test("(g) Swipe action, context menu and accessibility action all call the same request closure")
    func oneRequestClosureForAllEntryPoints() throws {
        let scope = try makeSUT()
        let row = try childRowBody(scope)
        let name = "onRequestDelete"
        let declarations = try Self.matches(#"\b(?:let|var)\s+onRequestDelete\b"#, in: row).count
        #expect(declarations == 1, "ChildRow must declare onRequestDelete once")
        let uses = try Self.matches(#"\bonRequestDelete\b"#, in: row).count - declarations
        #expect(uses == 3, "Expected exactly three uses of \(name) in ChildRow, found \(uses)")
        for marker in [#"\.swipeActions\s*\("#, #"\.contextMenu\b"#, #"\.accessibilityAction\s*\(\s*named\s*:"#] {
            let body = try #require(try Self.block(afterMatchOf: marker, in: row), "No block after \(marker)")
            #expect(try Self.matches(#"\bonRequestDelete\b"#, in: body).count == 1,
                    "The block after \(marker) must call onRequestDelete once")
        }
    }
}
