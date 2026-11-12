//
//  RecordPurchaseViewScanRules.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (f): the pure rule functions behind RecordPurchaseViewScanTests. Each takes the
//  source text and returns short violation descriptions (rule plus 1-based line), so the rules can
//  be proven on synthetic strings (positive and negative) before they are run over the real files.
//
//  Two views of a source are used:
//   - `code`: comments stripped (ItemSourceScan.codeOnly), string contents intact;
//   - `bare`: comments stripped AND string literal contents blanked, so words inside user-visible
//     text ("Record Purchase", "Done!") cannot trip a type-name or force-unwrap rule.
//  Line numbers are preserved by both.
//
//  The checks are conservative text checks, not a Swift parser.
//

import Foundation
@testable import ChristmasTracker

nonisolated enum RecordPurchaseViewRules {

    // MARK: Source views

    /// Blanks the contents of string literals ("..." and multi-line """...""") and keeps the quotes
    /// and every newline.
    static func bare(_ code: String) -> String {
        var result = ""
        let characters = Array(code)
        var index = 0
        while index < characters.count {
            if characters[index...].starts(with: Array("\"\"\"")) {
                result += "\"\"\""
                index += 3
                while index < characters.count, !characters[index...].starts(with: Array("\"\"\"")) {
                    if characters[index] == "\n" { result.append("\n") }
                    index += 1
                }
                if index < characters.count { result += "\"\"\""; index += 3 }
            } else if characters[index] == "\"" {
                result.append("\"")
                index += 1
                while index < characters.count, characters[index] != "\"", characters[index] != "\n" {
                    if characters[index] == "\\", index + 1 < characters.count { index += 1 }
                    index += 1
                }
                if index < characters.count, characters[index] == "\"" { result.append("\""); index += 1 }
            } else {
                result.append(characters[index])
                index += 1
            }
        }
        return result
    }

    private static func hits(_ pattern: String, in text: String, rule: String) -> [String] {
        ((try? ItemSourceScan.matchingLines(pattern, in: text)) ?? [-1]).map { "\(rule) at line \($0)" }
    }

    // MARK: Rules

    /// Legacy purchase and item types, the legacy bridge and the purchase history screen.
    static func legacyNameViolations(inBare text: String) -> [String] {
        let pattern = #"\b(GiftItem|Purchase|PurchasePerson|PurchaseResponse|PurchaseWarning|PurchaseSummary|ShippingStatus|PurchaseRepository|NetworkPurchaseRepository|MockPurchaseRepository|MockPurchaseData|PurchaseHistoryView|legacyPurchaseItem)\b"#
        return hits(pattern, in: text, rule: "legacy purchase or item name")
    }

    static func alertViolations(inBare text: String) -> [String] {
        hits(#"\.alert\("#, in: text, rule: ".alert(")
    }

    /// Any identifier that ends in token or tokens (confirmationToken, pendingToken, token). A design-token
    /// accessor such as `marker.tokenColor` is NOT a confirmation token and is allowed.
    static func tokenViolations(inBare text: String) -> [String] {
        hits(#"\b\w*[Tt]okens?\b"#, in: text, rule: "token reference")
    }

    static func doubleViolations(inBare text: String) -> [String] {
        hits(#"\bDouble\b|\.doubleValue\b|\bFloat\b|String\(format:"#, in: text, rule: "floating point on money")
    }

    static func combineAndDispatchViolations(inBare text: String) -> [String] {
        let pattern = #"import\s+(Combine|Dispatch)\b|\bDispatch(Queue|Group|Semaphore|WorkItem)\b|\bObservableObject\b|@Published\b|\.sink\s*[\(\{]|\bPassthroughSubject\b|\bCurrentValueSubject\b|Task\.sleep\(\s*nanoseconds"#
        return hits(pattern, in: text, rule: "Combine or GCD")
    }

    /// `x!`, `)!`, `]!`, `try!`, `as!`; the logical not (`!flag`) and `!=` are not force unwraps.
    static func forceUnwrapViolations(inBare text: String) -> [String] {
        hits(#"(?<=[A-Za-z0-9_\)\]])!(?!=)"#, in: text, rule: "force unwrap")
    }

    /// Any Log call or print in a view or the model, and any accessibility identifier with an interpolation.
    /// Runs on `code` (string contents intact) because the interpolation sits inside the literal.
    static func logAndIdentifierViolations(inCode text: String) -> [String] {
        hits(#"\b(Log[A-Za-z]*|print|NSLog|os_log|debugPrint)\("#, in: text, rule: "log or print call")
            + hits(#"accessibilityIdentifier\([^\n]*\\\("#, in: text, rule: "accessibility identifier with an interpolation")
    }

    /// Raw colors, system fonts and numeric spacing instead of the DesignSystem tokens.
    static func rawStyleViolations(inBare text: String) -> [String] {
        let names = "red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|white|black|gray"
        var found = hits(#"\bColor\.("# + names + #")\b"#, in: text, rule: "raw color")
        found += hits(#"\bColor\s*\(|\bUIColor\b"#, in: text, rule: "Color initialiser")
        found += hits(
            #"\.(foregroundStyle|foregroundColor|tint|background|fill|stroke)\(\s*\.("# + names + #")\b"#,
            in: text, rule: "raw system color"
        )
        found += ItemUIRules.rawRedLines(in: text).map { "raw red at line \($0)" }
        found += hits(
            #"\.font\(\s*(\.system|Font\.|\.(largeTitle|title[23]?|headline|subheadline|body|callout|footnote|caption[12]?)\b)"#,
            in: text, rule: "system font"
        )
        found += hits(#"\.padding\(\s*(\.[a-zA-Z]+\s*,\s*)?[1-9]"#, in: text, rule: "numeric padding")
        found += hits(#"spacing:\s*[1-9]"#, in: text, rule: "numeric spacing")
        found += hits(#"cornerRadius:\s*[1-9]"#, in: text, rule: "numeric corner radius")
        return found
    }

    // MARK: confirmationDialog

    static func confirmationDialogCount(inBare text: String) -> Int {
        ((try? ItemSourceScan.matchingLines(#"\.confirmationDialog\("#, in: text)) ?? []).count
    }

    /// The text of every Button declaration (call, closures and modifier chain) that carries a `.confirmationDialog(`.
    static func buttonsCarryingDialog(inBare text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bButton\s*[\(\{]"#) else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        var found: [String] = []
        for match in regex.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text) else { continue }
            let declaration = ItemUIRules.declaration(startingAt: range.lowerBound, in: text)
            if declaration.contains(".confirmationDialog(") { found.append(declaration) }
        }
        return found
    }
}
