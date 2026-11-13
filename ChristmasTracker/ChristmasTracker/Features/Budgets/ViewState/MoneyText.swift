//
//  MoneyText.swift
//  ChristmasTracker
//
//  I5a Story A: the one shared pure currency formatter for budgets and statistics.
//

import Foundation

nonisolated enum MoneyText {
    static func currency(_ value: Decimal, code: String, locale: Locale) -> String {
        value.formatted(Decimal.FormatStyle.Currency(code: code, locale: locale))
    }
}
