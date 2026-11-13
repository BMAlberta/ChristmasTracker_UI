//
//  DuplicateBudgetModel.swift
//  ChristmasTracker
//
//  I5a Story C: the logic of the duplicate sheet. The years offered and the default come from the
//  caller; the call goes through the BudgetService; an error is held only in this model's banner.
//  Nothing here is logged.
//

import Foundation
import Observation

@MainActor
@Observable
final class DuplicateBudgetModel {

    // MARK: - Dependencies

    private let source: Budget
    private let budgetService: BudgetService

    // MARK: - State

    let years: [Int]
    var selectedYear: Int?
    private(set) var isDuplicating = false
    private(set) var banner: InlineErrorBannerState?

    // MARK: - Initialization

    init(source: Budget, budgetService: BudgetService, years: [Int], defaultYear: Int?) {
        self.source = source
        self.budgetService = budgetService
        self.years = years
        self.selectedYear = defaultYear ?? years.first
    }

    var canDuplicate: Bool {
        selectedYear != nil && !isDuplicating
    }

    var sourceYear: Int { source.year }

    func dismissBanner() {
        banner = nil
    }

    func duplicate() async -> Budget? {
        guard canDuplicate, let target = selectedYear else { return nil }
        isDuplicating = true
        banner = nil
        defer { isDuplicating = false }
        do {
            let request = BudgetRequestBuilder.duplicate(fromYear: source.year, toYear: target)
            return try await budgetService.duplicate(request)
        } catch is CancellationError {
            return nil
        } catch let failure as BudgetError {
            banner = InlineErrorBannerState(
                message: failure.userMessage,
                actions: failure.isRetryable ? [.tryAgain, .dismiss] : [.dismiss]
            )
            return nil
        } catch {
            banner = InlineErrorBannerState(message: BudgetError.server.userMessage, actions: [.dismiss])
            return nil
        }
    }
}
