//
//  BudgetAmountParser.swift
//  ChristmasTracker
//
//  I5a Story A: locale-aware parser for budget amounts. Same lexical rules as the purchase
//  total parser, but zero is allowed (a budget may be 0). Exact: no Double on the way.
//

import Foundation

nonisolated enum BudgetAmountParser {

    /// 999999.99
    static let maximum = Decimal(sign: .plus, exponent: -2, significand: 99_999_999)

    /// ASCII digits plus the locale decimal separator only; at most two fraction digits; ".50" and "12."
    /// are accepted, the lone separator and the empty text are not. Value 0 up to `maximum` inclusive.
    static func parse(_ text: String, locale: Locale) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Character(locale.decimalSeparator ?? ".")
        let parts = trimmed.split(separator: separator, maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        let whole = parts[0]
        let fraction = parts.count == 2 ? parts[1] : ""
        let isDigits: (Substring) -> Bool = { $0.allSatisfy { ("0"..."9").contains($0) } }
        guard isDigits(whole), isDigits(fraction), fraction.count <= 2 else { return nil }
        guard !whole.isEmpty || !fraction.isEmpty else { return nil }
        let integerPart = whole.isEmpty ? "0" : String(whole)
        let canonical = fraction.isEmpty ? integerPart : "\(integerPart).\(fraction)"
        guard let value = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")),
              value >= 0, value <= maximum else { return nil }
        return value
    }
}
