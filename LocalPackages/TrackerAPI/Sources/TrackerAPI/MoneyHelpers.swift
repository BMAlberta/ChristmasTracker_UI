// MoneyHelpers.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

/// Returns nil for NaN or infinite values.
public func doubleToDecimal(_ value: Double) -> Decimal? {
    guard value.isFinite else { return nil }
    let formatted = String(format: "%.2f", value)
    return Decimal(string: formatted, locale: Locale(identifier: "en_US_POSIX"))
}

/// Converts a Decimal to the Double whose JSON encoding matches a 2-decimal string
/// representation of the value. Goes through a 2-decimal string to avoid
/// floating-point imprecision — never does arithmetic directly on the Decimal.
public func decimalToDouble(_ value: Decimal) -> Double {
    var rounded = Decimal()
    var mutable = value
    NSDecimalRound(&rounded, &mutable, 2, .plain)
    let formatted = (rounded as NSDecimalNumber).stringValue
    return Double(formatted) ?? (rounded as NSDecimalNumber).doubleValue
}
