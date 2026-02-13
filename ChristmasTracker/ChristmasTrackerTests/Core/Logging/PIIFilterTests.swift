//
//  PIIFilterTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/7/26.
//

import Testing
@testable import ChristmasTracker
@Suite("PIIFilter Tests")
struct PIIFilterTests {
    @Test("Redacts email addresses")
    func testEmailRedaction() {
        let input = "User email is john@example.com"
        let output = PIIFilter.redact(input)
        #expect(output == "User email is [REDACTED]")
    }
    @Test("Redacts Bearer tokens")
    func testBearerTokenRedaction() {
        let input = "Authorization: Bearer abc123xyz"
        let output = PIIFilter.redact(input)
        #expect(output == "Authorization: [REDACTED]")
    }
    @Test("Redacts SSN")
    func testSSNRedaction() {
        let input = "SSN: 123-45-6789"
        let output = PIIFilter.redact(input)
        #expect(output == "SSN: [REDACTED]")
    }
    @Test("Redacts credit card numbers")
    func testCreditCardRedaction() {
        let input = "Card: 1234567890123456"
        let output = PIIFilter.redact(input)
        #expect(output == "Card: [REDACTED]")
    }
    @Test("Preserves non-PII content")
    func testNonPIIPreserved() {
        let input = "User logged in successfully"
        let output = PIIFilter.redact(input)
        #expect(output == input)
    }
}
