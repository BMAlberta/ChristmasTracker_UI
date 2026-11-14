//
//  BudgetEditorModelHarness.swift
//  ChristmasTrackerTests
//
//  I5a Story C: shared construction and helpers for the BudgetEditorModel and DuplicateBudgetModel tests.
//
//  The editor is built over a REAL BudgetService (over GatedBudgetManager) and a REAL ListService (over
//  GatedListRepository with an in-memory ListDataStore). Determinism: gated fakes with the
//  nextHeldCall() handshake. No sleeps, no yield loops. Every held call is released by its test.
//
//  All names, ids and amounts are fake.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum EditorTest {
    static let locale = Locale(identifier: "en_US")

    static let alex = BudgetRecipientOption(id: "p-a", displayName: "Alex Giftee")
    static let casey = BudgetRecipientOption(id: "p-c", displayName: "Casey Spender")
    static let drew = BudgetRecipientOption(id: "p-d", displayName: "Drew Otherson")

    /// The budget of the edit tests: total 500.00, r1 Tommy 200.00, r2 Mike 250.00 (year 2026).
    static func original() -> Budget {
        BudgetFixtures.originalBudget()
    }

    /// What the server hands back after a save.
    static func stored(year: Int = 2026, total: String = "1000") -> Budget {
        BudgetServiceFix.budget(year, total: total)
    }

    static func list(_ option: BudgetRecipientOption, canPurchase: Bool = true, id: String? = nil) -> GiftList {
        BudgetFixtures.list(
            id: id ?? "list-\(option.id)", recipientId: option.id, recipientName: option.displayName,
            canPurchase: canPurchase
        )
    }
}

@MainActor
struct BudgetEditorSUT {
    let model: BudgetEditorModel
    let budgets: BudgetService
    let lists: ListService
    let manager: GatedBudgetManager
    let listRepo: GatedListRepository
}

@MainActor
func makeBudgetEditorSUT(
    mode: BudgetEditorModel.Mode = .create(years: [2026, 2027], defaultYear: 2026),
    spend: [RecipientSpend] = []
) -> BudgetEditorSUT {
    let manager = GatedBudgetManager()
    let listRepo = GatedListRepository()
    let budgets = BudgetService(repository: manager)
    let lists = ListService(repository: listRepo, dataStore: ListDataStore())
    let model = BudgetEditorModel(
        mode: mode,
        budgetService: budgets,
        listService: lists,
        spend: spend,
        locale: EditorTest.locale,
        currencyCode: "USD"
    )
    return BudgetEditorSUT(model: model, budgets: budgets, lists: lists, manager: manager, listRepo: listRepo)
}

/// An edit editor over `EditorTest.original()` (r1 Tommy 200.00, r2 Mike 250.00 of 500.00).
@MainActor
func makeEditEditorSUT(spend: [RecipientSpend] = []) -> BudgetEditorSUT {
    makeBudgetEditorSUT(mode: .edit(EditorTest.original()), spend: spend)
}

extension BudgetEditorSUT {
    /// Types a total, adds Alex with a limit: a create draft that is valid (total 1000, Alex 400).
    func fillValidCreateDraft() {
        model.setTotalText("1000")
        model.addPerson(EditorTest.alex)
        model.setLimitText("400", for: EditorTest.alex.id)
    }
}

/// One mutation failure and what the sheet must show for it. Shared by the editor and duplicate tests.
nonisolated struct MutationFailureCase: Sendable, CustomTestStringConvertible {
    let name: String
    let error: BudgetError
    let message: String
    let actions: [InlineErrorBannerAction]

    var testDescription: String { name }
}

nonisolated enum MutationFailureCases {
    static let nonRetryable: [MutationFailureCase] = [
        MutationFailureCase(
            name: "409 already exists", error: .alreadyExists(message: "You already have a budget for 2026."),
            message: "You already have a budget for 2026.", actions: [.dismiss]
        ),
        MutationFailureCase(
            name: "422 sum exceeds total", error: .sumExceedsTotal(message: "Limits add up to more than the total"),
            message: "Limits add up to more than the total", actions: [.dismiss]
        ),
        MutationFailureCase(
            name: "422 without a body uses the fixed text", error: .sumExceedsTotal(message: ""),
            message: "Limits add up to more than the total", actions: [.dismiss]
        ),
        MutationFailureCase(
            name: "400 invalid price", error: .validation(message: "Enter a valid amount."),
            message: "Enter a valid amount.", actions: [.dismiss]
        ),
        MutationFailureCase(
            name: "404 not found", error: .notFound,
            message: "That budget could not be found.", actions: [.dismiss]
        ),
        MutationFailureCase(
            name: "403 forbidden", error: .forbidden,
            message: "You don't have permission to do that.", actions: [.dismiss]
        )
    ]

    static let retryable: [MutationFailureCase] = [
        MutationFailureCase(
            name: "network", error: .network,
            message: "Check your connection and try again.", actions: [.tryAgain, .dismiss]
        ),
        MutationFailureCase(
            name: "server", error: .server,
            message: "Something went wrong. Please try again.", actions: [.tryAgain, .dismiss]
        ),
        MutationFailureCase(
            name: "429 rate limited", error: .rateLimited(retryAfter: 30),
            message: "Too many requests. Please wait a moment and try again.", actions: [.tryAgain, .dismiss]
        ),
        MutationFailureCase(
            name: "invalid response", error: .invalidResponse,
            message: "Something went wrong. Please try again.", actions: [.tryAgain, .dismiss]
        )
    ]

    static let all: [MutationFailureCase] = nonRetryable + retryable
}
