// MoneyHelpersTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import TrackerAPI

@Suite("Money helpers")
struct MoneyHelpersTests {

    // MARK: - doubleToDecimal — basic values

    @Test("doubleToDecimal(0.1) produces Decimal equal to 0.10")
    func doubleToDecimalZeroPointOne() throws {
        let result = try #require(doubleToDecimal(0.1))
        let expected = Decimal(string: "0.10", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    @Test("doubleToDecimal(0.07) produces Decimal equal to 0.07")
    func doubleToDecimalZeroPointZeroSeven() throws {
        let result = try #require(doubleToDecimal(0.07))
        let expected = Decimal(string: "0.07", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    @Test("doubleToDecimal(19.99) produces Decimal equal to 19.99")
    func doubleToDecimalNineteenNinetyNine() throws {
        let result = try #require(doubleToDecimal(19.99))
        let expected = Decimal(string: "19.99", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    @Test("doubleToDecimal(1234.5) produces Decimal equal to 1234.50")
    func doubleToDecimalOneThousandTwoThirtyFourPointFive() throws {
        let result = try #require(doubleToDecimal(1234.5))
        let expected = Decimal(string: "1234.50", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    @Test("doubleToDecimal(999999.99) produces Decimal equal to 999999.99")
    func doubleToDecimalLargeValue() throws {
        let result = try #require(doubleToDecimal(999_999.99))
        let expected = Decimal(string: "999999.99", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    @Test("doubleToDecimal(0) produces Decimal equal to 0.00")
    func doubleToDecimalZero() throws {
        let result = try #require(doubleToDecimal(0))
        let expectedZero = Decimal(string: "0", locale: Locale(identifier: "en_US_POSIX"))
        let expectedZeroZero = Decimal(string: "0.00", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expectedZero || result == expectedZeroZero)
    }

    @Test("doubleToDecimal(-5.25) produces Decimal equal to -5.25")
    func doubleToDecimalNegative() throws {
        let result = try #require(doubleToDecimal(-5.25))
        let expected = Decimal(string: "-5.25", locale: Locale(identifier: "en_US_POSIX"))
        #expect(result == expected)
    }

    // MARK: - doubleToDecimal — special float values return nil

    @Test("doubleToDecimal(NaN) returns nil")
    func doubleToDecimalNaN() {
        #expect(doubleToDecimal(Double.nan) == nil)
    }

    @Test("doubleToDecimal(+Infinity) returns nil")
    func doubleToDecimalPlusInfinity() {
        #expect(doubleToDecimal(Double.infinity) == nil)
    }

    @Test("doubleToDecimal(-Infinity) returns nil")
    func doubleToDecimalMinusInfinity() {
        #expect(doubleToDecimal(-Double.infinity) == nil)
    }

    // MARK: - doubleToDecimal — 0.1 + 0.2 round-trip

    @Test("doubleToDecimal(0.1) + doubleToDecimal(0.2) equals doubleToDecimal(0.3)")
    func additionRoundTrip() throws {
        let a = try #require(doubleToDecimal(0.1))
        let b = try #require(doubleToDecimal(0.2))
        let c = try #require(doubleToDecimal(0.3))
        #expect(a + b == c)
    }

    // MARK: - decimalToDouble — JSON encoding

    @Test("decimalToDouble(19.99) encodes to JSON as '19.99'")
    func decimalToDoubleJSONEncoding() throws {
        let d = try #require(Decimal(string: "19.99", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(d)
        let encoded = try JSONEncoder().encode(asDouble)
        let str = String(data: encoded, encoding: .utf8)
        #expect(str == "19.99")
    }

    // MARK: - decimalToDouble round-trips (Decimal VALUE equality)

    @Test("decimalToDouble round-trip for 0.10 preserves Decimal value")
    func roundTripZeroPointOne() throws {
        let original = try #require(Decimal(string: "0.10", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }

    @Test("decimalToDouble round-trip for 0.07 preserves Decimal value")
    func roundTripZeroPointZeroSeven() throws {
        let original = try #require(Decimal(string: "0.07", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }

    @Test("decimalToDouble round-trip for 19.99 preserves Decimal value")
    func roundTripNineteenNinetyNine() throws {
        let original = try #require(Decimal(string: "19.99", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }

    @Test("decimalToDouble round-trip for 1234.50 preserves Decimal value")
    func roundTripOneThousandTwoThirtyFourPointFive() throws {
        let original = try #require(Decimal(string: "1234.50", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }

    @Test("decimalToDouble round-trip for 999999.99 preserves Decimal value")
    func roundTripLargeValue() throws {
        let original = try #require(Decimal(string: "999999.99", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }

    @Test("decimalToDouble round-trip for 0 preserves Decimal value")
    func roundTripZero() throws {
        let original = try #require(Decimal(string: "0", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        let expectedZeroZero = Decimal(string: "0.00", locale: Locale(identifier: "en_US_POSIX"))
        #expect(backToDecimal == original || backToDecimal == expectedZeroZero)
    }

    @Test("decimalToDouble round-trip for -5.25 preserves Decimal value")
    func roundTripNegative() throws {
        let original = try #require(Decimal(string: "-5.25", locale: Locale(identifier: "en_US_POSIX")))
        let asDouble = decimalToDouble(original)
        let backToDecimal = try #require(doubleToDecimal(asDouble))
        #expect(backToDecimal == original)
    }
}
