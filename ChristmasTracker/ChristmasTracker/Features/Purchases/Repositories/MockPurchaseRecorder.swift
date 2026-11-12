//
//  MockPurchaseRecorder.swift
//  ChristmasTracker
//
//  Deterministic in-memory purchase recorder for mock mode and previews. It reproduces decision
//  S12 of the budget confirmation: an over-budget request without a valid token creates nothing and
//  answers `confirmationRequired` with one warning per exceeded level and ONE shared token; a valid
//  token records the purchase; ANY recorded purchase changes the spend, so every outstanding token
//  stops matching and a repeat over-budget purchase asks again with a NEW token.
//
//  Documented limitation: the mock does not change the mock items, so counts and status in mock
//  mode do not move after a mock purchase.
//

import Foundation

/// What the mock knows about the caller's right to buy an item, decided by the injected closure.
nonisolated enum MockPurchaseAccess: Sendable, Equatable {
    case allowed(recipient: ListItemPerson)
    case ownList
    case forbidden
    case unknown
}

nonisolated extension MockPurchaseAccess {
    /// The access mock mode uses: derived from the mock seed items and the flags of the list each
    /// item sits on, so mock mode never disagrees with itself. An item the seed does not hold, or
    /// one on a list the mock does not know, is unknown; a list the caller is the recipient of is
    /// their own; a list the caller may not buy from is forbidden. The recipient is a fake person
    /// per list (the mock lists carry no recipient record).
    static func fromMockSeed(itemId: String) -> MockPurchaseAccess {
        guard let item = MockItemSeed.items.first(where: { $0.id == itemId }),
              let capabilities = MockListRepository.capabilities(forListId: item.listId) else {
            return .unknown
        }
        if capabilities.isRecipient { return .ownList }
        if !capabilities.canPurchase { return .forbidden }
        return .allowed(recipient: ListItemPerson(id: "mock-recipient-\(item.listId)", displayName: "List Recipient"))
    }
}

/// Documented mock data: the budgets the mock enforces and how long a token lasts.
nonisolated enum MockPurchaseRules {
    static let recipientBudgetLimit: Decimal = 50
    static let totalBudgetLimit: Decimal = 50
    static let tokenLifetime: TimeInterval = 300
}

// Mock recorder: intentionally uninstrumented (an actor, and a mock).
actor MockPurchaseRecorder: PurchaseRecording {

    /// What a token was issued for. A token only works while every part still matches.
    private struct IssuedToken {
        let itemId: String
        let quantity: Int
        let amount: Decimal
        let recipientSpend: Decimal
        let totalSpend: Decimal
        let expiresAt: Date
    }

    private static let maximumAmount = Decimal(99_999_999) / 100

    // MARK: - State

    private let access: @Sendable (_ itemId: String) -> MockPurchaseAccess
    private let buyer: ListItemPerson
    private let now: @Sendable () -> Date
    /// When set, every recorded purchase is appended so the mock manager can open it.
    private let store: MockPurchaseStore?

    private var totalSpend: Decimal = 0
    private var spendByRecipient: [String: Decimal] = [:]
    private var issuedTokens: [String: IssuedToken] = [:]
    private var nextPurchaseNumber = 1
    private var nextTokenNumber = 1

    // MARK: - Initialization

    init(
        access: @escaping @Sendable (_ itemId: String) -> MockPurchaseAccess,
        buyer: ListItemPerson = MockItemRepository.defaultUser,
        now: @escaping @Sendable () -> Date = { Date() },
        store: MockPurchaseStore? = nil
    ) {
        self.access = access
        self.buyer = buyer
        self.now = now
        self.store = store
    }

    // MARK: - PurchaseRecording

    func createPurchase(
        itemId: String,
        draft: PurchaseDraft,
        confirmationToken: String?
    ) async throws -> PurchaseOutcome {
        let recipient = try recipientForPurchase(itemId: itemId)
        guard draft.quantity >= 1 else {
            throw RecordPurchaseError.validation(message: "Quantity must be at least 1.")
        }
        guard isValidAmount(draft.totalCost) else { throw RecordPurchaseError.invalidPrice }

        let recipientSpend = spendByRecipient[recipient.id] ?? 0
        let overRecipient = recipientSpend + draft.totalCost > MockPurchaseRules.recipientBudgetLimit
        let overTotal = totalSpend + draft.totalCost > MockPurchaseRules.totalBudgetLimit

        guard overRecipient || overTotal else {
            return .created(await record(itemId: itemId, draft: draft, recipient: recipient))
        }

        let currentTime = now()
        issuedTokens = issuedTokens.filter { $0.value.expiresAt > currentTime }
        if let confirmationToken, let issued = issuedTokens[confirmationToken],
           issued.itemId == itemId, issued.quantity == draft.quantity, issued.amount == draft.totalCost,
           issued.recipientSpend == recipientSpend, issued.totalSpend == totalSpend {
            return .created(await record(itemId: itemId, draft: draft, recipient: recipient))
        }

        // No token, or an expired, unknown or mismatched one: a fresh confirmation, never an error.
        var warnings: [BudgetWarning] = []
        if overRecipient {
            warnings.append(BudgetWarning(
                level: .recipient,
                recipientName: recipient.displayName,
                budgetLimit: MockPurchaseRules.recipientBudgetLimit,
                currentSpent: recipientSpend,
                purchaseAmount: draft.totalCost,
                overage: recipientSpend + draft.totalCost - MockPurchaseRules.recipientBudgetLimit
            ))
        }
        if overTotal {
            warnings.append(BudgetWarning(
                level: .total,
                recipientName: nil,
                budgetLimit: MockPurchaseRules.totalBudgetLimit,
                currentSpent: totalSpend,
                purchaseAmount: draft.totalCost,
                overage: totalSpend + draft.totalCost - MockPurchaseRules.totalBudgetLimit
            ))
        }
        let token = "mock-token-\(nextTokenNumber)"
        nextTokenNumber += 1
        issuedTokens[token] = IssuedToken(
            itemId: itemId,
            quantity: draft.quantity,
            amount: draft.totalCost,
            recipientSpend: recipientSpend,
            totalSpend: totalSpend,
            expiresAt: currentTime.addingTimeInterval(MockPurchaseRules.tokenLifetime)
        )
        return .confirmationRequired(warnings: warnings, token: token)
    }

    // MARK: - Private

    private func recipientForPurchase(itemId: String) throws -> ListItemPerson {
        switch access(itemId) {
        case .allowed(let recipient): return recipient
        case .ownList: throw RecordPurchaseError.cannotPurchaseOwnList
        case .forbidden: throw RecordPurchaseError.forbidden
        case .unknown: throw RecordPurchaseError.notFound
        }
    }

    /// Greater than 0, at most 999999.99 and at most two decimals.
    private func isValidAmount(_ amount: Decimal) -> Bool {
        guard amount > 0, amount <= Self.maximumAmount else { return false }
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded == amount
    }

    /// Records the purchase. The spend changes, so every outstanding token is dropped.
    private func record(itemId: String, draft: PurchaseDraft, recipient: ListItemPerson) async -> RecordedPurchase {
        let date = now()
        let purchase = RecordedPurchase(
            id: "mock-purchase-\(nextPurchaseNumber)",
            itemId: itemId,
            quantity: draft.quantity,
            totalCost: draft.totalCost,
            storeName: draft.storeName,
            notes: draft.notes,
            confirmationNumber: draft.confirmationNumber,
            trackingNumber: draft.trackingNumber,
            shippingStatus: .notTracked,
            shippedAt: nil,
            deliveredAt: nil,
            purchaser: buyer,
            recipient: recipient,
            purchasedAt: date,
            createdAt: date,
            updatedAt: date
        )
        nextPurchaseNumber += 1
        totalSpend += draft.totalCost
        spendByRecipient[recipient.id, default: 0] += draft.totalCost
        issuedTokens.removeAll()
        // All spend state is updated above, before this suspension point.
        await store?.add(purchase)
        return purchase
    }
}
