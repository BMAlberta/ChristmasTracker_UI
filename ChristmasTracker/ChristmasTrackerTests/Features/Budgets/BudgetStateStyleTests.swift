//
//  BudgetStateStyleTests.swift
//  ChristmasTrackerTests
//
//  TH1-T3: the pure budget level rule and its style. Over when spent > limit; near when spent is at
//  least 90 percent of a positive limit and not over; otherwise under.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetStateStyle")
struct BudgetStateStyleTests {

    private func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func level(_ spent: String, of limit: String) -> BudgetLevel {
        BudgetStateStyle.level(spent: dec(spent), limit: dec(limit))
    }

    // MARK: - Constant

    @Test func thresholdIsNinetyPercent() {
        #expect(BudgetStateStyle.nearLimitThreshold == dec("0.9"))
    }

    @Test func thereAreThreeLevels() {
        #expect(BudgetLevel.allCases.count == 3)
    }

    // MARK: - Level

    @Test func halfSpentIsUnder() { #expect(level("50", of: "100") == .under) }
    @Test func nothingSpentIsUnder() { #expect(level("0", of: "100") == .under) }
    @Test func justUnderNinetyPercentIsUnder() { #expect(level("89.99", of: "100") == .under) }
    @Test func exactlyNinetyPercentIsNear() { #expect(level("90", of: "100") == .nearLimit) }
    @Test func betweenNinetyAndLimitIsNear() { #expect(level("95", of: "100") == .nearLimit) }
    @Test func justUnderLimitIsNear() { #expect(level("99.99", of: "100") == .nearLimit) }
    @Test func exactlyAtLimitIsNear() { #expect(level("100", of: "100") == .nearLimit) }
    @Test func oneCentOverIsOver() { #expect(level("100.01", of: "100") == .over) }
    @Test func overByNineteenNinetyEightIsOver() { #expect(level("619.98", of: "600") == .over) }
    @Test func wellOverIsOver() { #expect(level("1050.50", of: "500") == .over) }

    @Test func thresholdScalesWithTheLimit() {
        #expect(level("539.99", of: "600") == .under)
        #expect(level("540", of: "600") == .nearLimit)
    }

    // MARK: - Limit zero

    @Test func zeroLimitAndZeroSpentIsUnder() { #expect(level("0", of: "0") == .under) }
    @Test func zeroLimitWithSpendingIsOver() { #expect(level("0.01", of: "0") == .over) }
    @Test func zeroLimitWithLargeSpendingIsOver() { #expect(level("12.34", of: "0") == .over) }

    // MARK: - Zero and negative spent

    @Test func negativeSpentIsUnder() { #expect(level("-5", of: "100") == .under) }
    @Test func negativeSpentWithZeroLimitIsUnder() { #expect(level("-5", of: "0") == .under) }
    @Test func zeroSpentIsAlwaysUnderForAPositiveLimit() { #expect(level("0", of: "0.01") == .under) }

    // MARK: - Style per level

    @Test func underStyle() {
        let style = BudgetStateStyle.style(for: .under)
        #expect(style.level == .under)
        #expect(style.token == .budgetSafe)
        #expect(style.label == "Under budget")
        #expect(style.accessibilityLabel == "Budget: Under budget")
    }

    @Test func nearLimitStyle() {
        let style = BudgetStateStyle.style(for: .nearLimit)
        #expect(style.level == .nearLimit)
        #expect(style.token == .budgetWarningBar)
        #expect(style.label == "Near limit")
        #expect(style.accessibilityLabel == "Budget: Near limit")
    }

    @Test func overStyle() {
        let style = BudgetStateStyle.style(for: .over)
        #expect(style.level == .over)
        #expect(style.token == .budgetOver)
        #expect(style.label == "Over budget")
        #expect(style.accessibilityLabel == "Budget: Over budget")
    }

    @Test func accessibilityLabelIsBudgetColonLabelForEveryLevel() {
        for level in BudgetLevel.allCases {
            let style = BudgetStateStyle.style(for: level)
            #expect(style.accessibilityLabel == "Budget: " + style.label)
        }
    }

    @Test func tokensAreDistinctAcrossLevels() {
        let tokens = BudgetLevel.allCases.map { BudgetStateStyle.style(for: $0).token }
        #expect(Set(tokens).count == 3)
    }
}
