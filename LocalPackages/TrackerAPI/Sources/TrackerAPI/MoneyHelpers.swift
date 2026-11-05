// MoneyHelpers.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

/// Converts a Double (from the generated API client's Money type) to a Decimal
/// rounded to exactly 2 decimal places. Goes through a 2-decimal string to avoid
/// floating-point imprecision — never does arithmetic directly on the Double.
/// Constructs the Decimal with exponent -2 to preserve trailing zeros in .description.
public func doubleToDecimal(_ value: Double) -> Decimal {
    let formatted = String(format: "%.2f", value)
    let isNegative = formatted.hasPrefix("-")
    let cleanedStr = isNegative ? String(formatted.dropFirst()) : formatted

    let parts = cleanedStr.split(separator: ".", maxSplits: 1)
    guard parts.count == 2,
          let intPart = Int64(parts[0]),
          let fracPart = Int64(parts[1]) else {
        return Decimal(string: formatted) ?? Decimal(value)
    }

    let mantissaInt = intPart * 100 + fracPart

    // Build a Decimal with exponent -2 so .description preserves trailing zeros.
    // Decimal stores mantissa as little-endian UInt16 words (_length words used).
    var d = Decimal()
    d._exponent = -2
    d._isNegative = isNegative ? 1 : 0
    d._isCompact = 0
    d._reserved = 0

    let m = UInt64(bitPattern: mantissaInt)
    let w0 = UInt16(m & 0xFFFF)
    let w1 = UInt16((m >> 16) & 0xFFFF)
    let w2 = UInt16((m >> 32) & 0xFFFF)
    let w3 = UInt16((m >> 48) & 0xFFFF)

    d._mantissa = (w0, w1, w2, w3, 0, 0, 0, 0)
    if w3 != 0 {
        d._length = 4
    } else if w2 != 0 {
        d._length = 3
    } else if w1 != 0 {
        d._length = 2
    } else {
        d._length = 1
    }
    return d
}

/// Converts a Decimal to the Double that JSON would encode as the same 2-decimal value.
/// Rounds to 2 decimal places first, then converts via NSDecimalNumber.
public func decimalToDouble(_ value: Decimal) -> Double {
    var rounded = Decimal()
    var mutable = value
    NSDecimalRound(&rounded, &mutable, 2, .plain)
    return NSDecimalNumber(decimal: rounded).doubleValue
}
