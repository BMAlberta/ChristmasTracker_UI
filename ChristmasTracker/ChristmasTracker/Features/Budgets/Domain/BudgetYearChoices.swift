//
//  BudgetYearChoices.swift
//  ChristmasTracker
//
//  I5a Story A: which years the pickers offer. The current year is always injected.
//

import Foundation

nonisolated enum BudgetYearChoices {

    private static let allowed = 2000...2100

    static func currentYear(now: Date, calendar: Calendar) -> Int {
        calendar.component(.year, from: now)
    }

    /// Union of the sources plus the current year, newest first, no duplicates.
    static func pickerYears(availableYears: [Int], budgetYears: [Int], currentYear: Int) -> [Int] {
        Set(availableYears).union(budgetYears).union([currentYear]).sorted(by: >)
    }

    /// currentYear-1 through currentYear+3 ascending, without years that have a budget.
    static func createYears(budgetYears: [Int], currentYear: Int) -> [Int] {
        free(from: currentYear - 1, through: currentYear + 3, budgetYears: budgetYears)
    }

    static func defaultCreateYear(budgetYears: [Int], currentYear: Int) -> Int? {
        let years = createYears(budgetYears: budgetYears, currentYear: currentYear)
        if years.contains(currentYear) { return currentYear }
        return years.first { $0 > currentYear } ?? years.first
    }

    /// currentYear+1 through currentYear+3 ascending, without years that have a budget.
    static func duplicateYears(budgetYears: [Int], currentYear: Int) -> [Int] {
        free(from: currentYear + 1, through: currentYear + 3, budgetYears: budgetYears)
    }

    static func defaultDuplicateYear(budgetYears: [Int], currentYear: Int) -> Int? {
        duplicateYears(budgetYears: budgetYears, currentYear: currentYear).first
    }

    private static func free(from start: Int, through end: Int, budgetYears: [Int]) -> [Int] {
        let taken = Set(budgetYears)
        return (start...end).filter { allowed.contains($0) && !taken.contains($0) }
    }
}
