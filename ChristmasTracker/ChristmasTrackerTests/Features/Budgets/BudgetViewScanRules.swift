//
//  BudgetViewScanRules.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the pure rule functions behind BudgetViewScanTests. Each takes source text and returns
//  short violation descriptions (rule plus 1-based line), so every rule can be proven on synthetic strings
//  (positive and negative) before it runs over the real files. The rules are conservative text checks, not
//  a Swift parser.
//
//  Two views of a source are used (see RecordPurchaseViewRules):
//   - `code`: comments stripped, string contents intact;
//   - `bare`: comments stripped AND string literal contents blanked, so words inside user-visible text
//     cannot trip a rule.
//
//  The words of the forbidden concurrency APIs are never written literally in this file: they come from
//  BudgetScan (built from pieces) and from the pieces below.
//

import Foundation

nonisolated enum BudgetViewRules {

    private static let colorNames = "red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|white|black|gray"

    private static func hits(_ pattern: String, in text: String, rule: String) -> [String] {
        ((try? ItemSourceScan.matchingLines(pattern, in: text)) ?? [-1]).map { "\(rule) at line \($0)" }
    }

    // MARK: Design tokens (run on bare)

    static func rawColorViolations(inBare text: String) -> [String] {
        var found = hits(#"\bColor\.("# + colorNames + #")\b"#, in: text, rule: "raw color")
        found += hits(#"\bColor\s*\(|\bUIColor\b"#, in: text, rule: "Color initialiser")
        found += hits(
            #"\.(foregroundStyle|tint|background|fill|stroke)\(\s*\.("# + colorNames + #")\b"#,
            in: text, rule: "raw system color"
        )
        return found
    }

    static func foregroundColorViolations(inBare text: String) -> [String] {
        hits(#"\.foregroundColor\("#, in: text, rule: "foregroundColor")
    }

    static func systemFontViolations(inBare text: String) -> [String] {
        hits(
            #"\.font\(\s*(\.system|Font\.|\.(largeTitle|title[23]?|headline|subheadline|body|callout|footnote|caption[12]?)\b)"#,
            in: text, rule: "system font"
        )
    }

    /// Numeric literals in padding, spacing and frame calls. `InlineErrorBannerState.minimumButtonHeight` has no digit, so the
    /// allowed 44-point token passes without a special case.
    static func numericLayoutViolations(inBare text: String) -> [String] {
        var found = hits(#"\.padding\(\s*(\.[a-zA-Z]+\s*,\s*)?[0-9]"#, in: text, rule: "numeric padding")
        found += hits(#"spacing:\s*[0-9]"#, in: text, rule: "numeric spacing")
        found += hits(#"\.frame\([^)\n]*\b[0-9]"#, in: text, rule: "numeric frame")
        return found
    }

    /// Every design-token rule together.
    static func tokenViolations(inBare text: String) -> [String] {
        rawColorViolations(inBare: text) + foregroundColorViolations(inBare: text)
            + systemFontViolations(inBare: text) + numericLayoutViolations(inBare: text)
    }

    // MARK: SwiftUI rules of the brief (run on bare)

    static func swiftUIRuleViolations(inBare text: String) -> [String] {
        var found = hits(#"\.onTapGesture\b"#, in: text, rule: "onTapGesture instead of Button")
        found += hits(#"\bAnyView\b"#, in: text, rule: "AnyView")
        found += hits(#"\bGeometryReader\b|\bUIScreen\b"#, in: text, rule: "GeometryReader or UIScreen")
        found += hits(#"\.cornerRadius\("#, in: text, rule: "cornerRadius modifier")
        found += hits(#"ForEach\([^)\n]*\.indices"#, in: text, rule: "ForEach over indices")
        found += hits(#"\.sheet\(\s*isPresented"#, in: text, rule: "sheet(isPresented:) instead of sheet(item:)")
        return found
    }

    // MARK: Identifiers, logs, errors, concurrency

    /// An accessibility identifier with an interpolation. Runs on `code` (the interpolation sits in the literal).
    static func identifierInterpolationViolations(inCode text: String) -> [String] {
        hits(#"accessibilityIdentifier\([^\n]*\\\("#, in: text, rule: "accessibility identifier with an interpolation")
    }

    /// Any log, print or Sentry reference.
    static func logAndSentryViolations(inBare text: String) -> [String] {
        hits(#"\b(Log[A-Z][A-Za-z]*|print|NSLog|os_log|debugPrint)\("#, in: text, rule: "log or print call")
            + hits(#"\bimport\s+Sentry\b|\bSentry[A-Za-z]*\b"#, in: text, rule: "Sentry")
    }

    /// An interpolated, described or localized error (runs on `code`).
    static func errorInterpolationViolations(inCode text: String) -> [String] {
        BudgetScan.rawErrorViolations(in: text)
    }

    /// GCD, Combine and the Combine-era observation types.
    static func concurrencyViolations(inCode text: String) -> [String] {
        let observable: String = "Observable" + "Object"
        let published: String = "@" + "Published"
        var found = BudgetScan.concurrencyViolations(in: text)
        for word in [observable, published] where text.contains(word) {
            found.append("forbidden API \(word)")
        }
        return found
    }

    /// A `Text(` whose argument names an error, failure, message or banner: an ad-hoc error row.
    /// Runs on bare so that words in literals do not count; `emptyMessage` or `deleteMessage` do not match.
    static func adHocErrorTextViolations(inBare text: String) -> [String] {
        hits(
            #"\bText\(\s*(verbatim:\s*)?[^)\n]*\b(error|err|failure|errorMessage|failureMessage|message|banner|loadFailure)\b"#,
            in: text, rule: "ad-hoc error Text"
        )
    }

    // MARK: confirmationDialog and containers (run on bare)

    static func confirmationDialogCount(inBare text: String) -> Int {
        ((try? ItemSourceScan.matchingLines(#"\.confirmationDialog\("#, in: text)) ?? []).count
    }

    /// The text of every `Menu` declaration (call, closures and modifier chain) that carries a `.confirmationDialog(`.
    static func menusCarryingDialog(inBare text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bMenu\s*[\(\{]"#) else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        var found: [String] = []
        for match in regex.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text) else { continue }
            let declaration = ItemUIRules.declaration(startingAt: range.lowerBound, in: text)
            if declaration.contains(".confirmationDialog(") { found.append(declaration) }
        }
        return found
    }

    /// List, ScrollView, Form and NavigationStack as whole words.
    static func containerViolations(inBare text: String) -> [String] {
        hits(#"\b(List|ScrollView|Form|NavigationStack)\b"#, in: text, rule: "screen container")
    }

    /// `role: .destructive` without Color.destructiveColor anywhere in the file, or the token without the role.
    static func destructiveViolations(inCode text: String) -> [String] {
        var found: [String] = []
        if !text.contains("role: .destructive") { found.append("no role: .destructive") }
        if !text.contains("Color.destructiveColor") { found.append("no Color.destructiveColor") }
        return found
    }
}
