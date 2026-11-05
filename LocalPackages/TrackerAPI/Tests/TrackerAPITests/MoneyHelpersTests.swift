// MoneyHelpersTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import TrackerAPI

@Suite("Money helpers")
struct MoneyHelpersTests {

    // MARK: - doubleToDecimal

    @Test("doubleToDecimal(0.1) produces '0.10'")
    func doubleToDecimalZeroPointOne() {
        let result = doubleToDecimal(0.1)
        // Decimal string representation must be exactly two decimal places
        // and must NOT be the full IEEE 754 representation of the Double 0.1
        #expect(result.description == "0.10")
    }

    @Test("doubleToDecimal(0.07) produces '0.07'")
    func doubleToDecimalZeroPointZeroSeven() {
        let result = doubleToDecimal(0.07)
        #expect(result.description == "0.07")
    }

    @Test("doubleToDecimal(19.99) produces '19.99'")
    func doubleToDecimalNineteenNinetyNine() {
        let result = doubleToDecimal(19.99)
        #expect(result.description == "19.99")
    }

    @Test("doubleToDecimal(1234.5) produces '1234.50'")
    func doubleToDecimalOneThousandTwoThirtyFourPointFive() {
        let result = doubleToDecimal(1234.5)
        #expect(result.description == "1234.50")
    }

    @Test("doubleToDecimal(999999.99) produces '999999.99'")
    func doubleToDecimalLargeValue() {
        let result = doubleToDecimal(999_999.99)
        #expect(result.description == "999999.99")
    }

    @Test("doubleToDecimal(0) produces '0' or '0.00'")
    func doubleToDecimalZero() {
        let result = doubleToDecimal(0)
        // Both "0" and "0.00" are acceptable
        #expect(result.description == "0" || result.description == "0.00")
    }

    @Test("doubleToDecimal(-5.25) produces '-5.25'")
    func doubleToDecimalNegative() {
        let result = doubleToDecimal(-5.25)
        #expect(result.description == "-5.25")
    }

    // MARK: - decimalToDouble round-trip

    @Test("decimalToDouble round-trip for 0.1 preserves string representation")
    func roundTripZeroPointOne() {
        let original = Decimal(string: "0.10")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "0.10")
    }

    @Test("decimalToDouble round-trip for 0.07 preserves string representation")
    func roundTripZeroPointZeroSeven() {
        let original = Decimal(string: "0.07")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "0.07")
    }

    @Test("decimalToDouble round-trip for 19.99 preserves string representation")
    func roundTripNineteenNinetyNine() {
        // The key contract: 19.99 must not become 19.9900000000000...
        let original = Decimal(string: "19.99")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "19.99")
    }

    @Test("decimalToDouble round-trip for 1234.5 preserves string representation")
    func roundTripOneThousandTwoThirtyFourPointFive() {
        let original = Decimal(string: "1234.50")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "1234.50")
    }

    @Test("decimalToDouble round-trip for 999999.99 preserves string representation")
    func roundTripLargeValue() {
        let original = Decimal(string: "999999.99")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "999999.99")
    }

    @Test("decimalToDouble round-trip for 0 preserves string representation")
    func roundTripZero() {
        let original = Decimal(string: "0")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "0" || backToDecimal.description == "0.00")
    }

    @Test("decimalToDouble round-trip for -5.25 preserves string representation")
    func roundTripNegative() {
        let original = Decimal(string: "-5.25")!
        let asDouble = decimalToDouble(original)
        let backToDecimal = doubleToDecimal(asDouble)
        #expect(backToDecimal.description == "-5.25")
    }
}
