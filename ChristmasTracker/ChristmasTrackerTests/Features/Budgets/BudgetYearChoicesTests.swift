//
//  BudgetYearChoicesTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: BudgetYearChoices truth tables.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetYearChoices")
struct BudgetYearChoicesTests {

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return try #require(calendar("UTC").date(from: components))
    }

    // MARK: - currentYear

    @Test func currentYearInMidYear() throws {
        let now = try utcDate(2026, 6, 15, hour: 12)
        #expect(BudgetYearChoices.currentYear(now: now, calendar: calendar("UTC")) == 2026)
    }

    @Test func currentYearAtTheUTCYearBoundary() throws {
        let lastSecondish = try utcDate(2026, 12, 31, hour: 23)
        let firstHour = try utcDate(2027, 1, 1, hour: 0)
        #expect(BudgetYearChoices.currentYear(now: lastSecondish, calendar: calendar("UTC")) == 2026)
        #expect(BudgetYearChoices.currentYear(now: firstHour, calendar: calendar("UTC")) == 2027)
    }

    @Test func currentYearUsesTheCalendarTimeZoneWestOfUTC() throws {
        // 2027-01-01 03:00 UTC is still 2026-12-31 in Los Angeles.
        let now = try utcDate(2027, 1, 1, hour: 3)
        #expect(BudgetYearChoices.currentYear(now: now, calendar: calendar("America/Los_Angeles")) == 2026)
        #expect(BudgetYearChoices.currentYear(now: now, calendar: calendar("UTC")) == 2027)
    }

    @Test func currentYearUsesTheCalendarTimeZoneEastOfUTC() throws {
        // 2026-12-31 20:00 UTC is already 2027-01-01 in Tokyo.
        let now = try utcDate(2026, 12, 31, hour: 20)
        #expect(BudgetYearChoices.currentYear(now: now, calendar: calendar("Asia/Tokyo")) == 2027)
        #expect(BudgetYearChoices.currentYear(now: now, calendar: calendar("UTC")) == 2026)
    }

    // MARK: - pickerYears

    @Test func pickerYearsAreTheUnionPlusCurrentNewestFirst() {
        let result = BudgetYearChoices.pickerYears(availableYears: [2024, 2025], budgetYears: [2026, 2025], currentYear: 2026)
        #expect(result == [2026, 2025, 2024])
    }

    @Test func pickerYearsIncludeTheCurrentYearWhenAbsentFromBothSources() {
        let result = BudgetYearChoices.pickerYears(availableYears: [2023], budgetYears: [2024], currentYear: 2026)
        #expect(result == [2026, 2024, 2023])
    }

    @Test func pickerYearsWithNoSourcesIsJustTheCurrentYear() {
        #expect(BudgetYearChoices.pickerYears(availableYears: [], budgetYears: [], currentYear: 2026) == [2026])
    }

    @Test func pickerYearsHaveNoDuplicatesAndIgnoreInputOrder() {
        let result = BudgetYearChoices.pickerYears(
            availableYears: [2024, 2027, 2024],
            budgetYears: [2027, 2025, 2026],
            currentYear: 2026
        )
        #expect(result == [2027, 2026, 2025, 2024])
    }

    // MARK: - createYears

    @Test func createYearsWithNoBudgets() {
        #expect(BudgetYearChoices.createYears(budgetYears: [], currentYear: 2026) == [2025, 2026, 2027, 2028, 2029])
    }

    @Test func createYearsExcludeYearsThatHaveABudget() {
        let result = BudgetYearChoices.createYears(budgetYears: [2026, 2028], currentYear: 2026)
        #expect(result == [2025, 2027, 2029])
    }

    @Test func createYearsIgnoreBudgetsOutsideTheWindow() {
        let result = BudgetYearChoices.createYears(budgetYears: [2020, 2040], currentYear: 2026)
        #expect(result == [2025, 2026, 2027, 2028, 2029])
    }

    @Test func createYearsAreEmptyWhenEveryYearHasABudget() {
        let result = BudgetYearChoices.createYears(budgetYears: [2025, 2026, 2027, 2028, 2029], currentYear: 2026)
        #expect(result.isEmpty)
    }

    @Test func createYearsClampAtTheLowerBound() {
        #expect(BudgetYearChoices.createYears(budgetYears: [], currentYear: 2000) == [2000, 2001, 2002, 2003])
        #expect(BudgetYearChoices.createYears(budgetYears: [], currentYear: 2001) == [2000, 2001, 2002, 2003, 2004])
    }

    @Test func createYearsClampAtTheUpperBound() {
        #expect(BudgetYearChoices.createYears(budgetYears: [], currentYear: 2100) == [2099, 2100])
        #expect(BudgetYearChoices.createYears(budgetYears: [], currentYear: 2099) == [2098, 2099, 2100])
    }

    // MARK: - defaultCreateYear

    @Test func defaultCreateYearIsTheCurrentYearWhenFree() {
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: [2025], currentYear: 2026) == 2026)
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: [], currentYear: 2026) == 2026)
    }

    @Test func defaultCreateYearIsTheNextFreeYearWhenCurrentIsTaken() {
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: [2026], currentYear: 2026) == 2027)
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: [2026, 2027], currentYear: 2026) == 2028)
    }

    @Test func defaultCreateYearFallsBackToTheFirstCreateYearWhenOnlyEarlierIsFree() {
        let taken = [2026, 2027, 2028, 2029]
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: taken, currentYear: 2026) == 2025)
    }

    @Test func defaultCreateYearIsNilWhenAllAreTaken() {
        let taken = [2025, 2026, 2027, 2028, 2029]
        #expect(BudgetYearChoices.defaultCreateYear(budgetYears: taken, currentYear: 2026) == nil)
    }

    // MARK: - duplicateYears

    @Test func duplicateYearsAreTheNextThreeYears() {
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [], currentYear: 2026) == [2027, 2028, 2029])
    }

    @Test func duplicateYearsExcludeYearsWithABudget() {
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [2027], currentYear: 2026) == [2028, 2029])
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [2026, 2028], currentYear: 2026) == [2027, 2029])
    }

    @Test func duplicateYearsAreEmptyWhenAllTaken() {
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [2027, 2028, 2029], currentYear: 2026).isEmpty)
    }

    @Test func duplicateYearsClampAtTheBounds() {
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [], currentYear: 2099) == [2100])
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [], currentYear: 2100).isEmpty)
        #expect(BudgetYearChoices.duplicateYears(budgetYears: [], currentYear: 1998) == [2000, 2001])
    }

    // MARK: - defaultDuplicateYear

    @Test func defaultDuplicateYearIsTheFirstFreeYearAfterCurrent() {
        #expect(BudgetYearChoices.defaultDuplicateYear(budgetYears: [], currentYear: 2026) == 2027)
        #expect(BudgetYearChoices.defaultDuplicateYear(budgetYears: [2027], currentYear: 2026) == 2028)
        #expect(BudgetYearChoices.defaultDuplicateYear(budgetYears: [2027, 2028], currentYear: 2026) == 2029)
    }

    @Test func defaultDuplicateYearIsNilWhenNothingIsFree() {
        #expect(BudgetYearChoices.defaultDuplicateYear(budgetYears: [2027, 2028, 2029], currentYear: 2026) == nil)
        #expect(BudgetYearChoices.defaultDuplicateYear(budgetYears: [], currentYear: 2100) == nil)
    }
}
