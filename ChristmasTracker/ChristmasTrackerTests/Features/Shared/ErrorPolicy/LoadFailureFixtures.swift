//
//  LoadFailureFixtures.swift
//  ChristmasTrackerTests
//
//  UX1a Story U1: shared builders for the pure load-failure policy tests. Fake data only.
//

import Foundation
@testable import ChristmasTracker

enum LoadFailureFixtures {

    static let connectivity: [LoadFailureCategory] = [.unreachable, .timeout, .server]
    static let plainCategories: [LoadFailureCategory] = [.rateLimited, .forbidden, .other]

    /// A failure whose message is unique per category and source unless one is given.
    static func failure(
        _ category: LoadFailureCategory,
        _ source: LoadSource = .lists,
        message: String? = nil,
        retryAfter: Int? = nil
    ) -> LoadFailure {
        LoadFailure(
            category: category,
            source: source,
            retryAfter: retryAfter,
            plainMessage: message ?? defaultMessage(category, source)
        )
    }

    static func defaultMessage(_ category: LoadFailureCategory, _ source: LoadSource) -> String {
        "fake message \(category) \(source)"
    }

    static func banner(_ message: String, _ targets: [LoadSource]) -> LoadBanner {
        LoadBanner(message: message, retryTargets: targets)
    }

    /// The banner a single, plain-message group would produce.
    static func plainBanner(_ category: LoadFailureCategory, _ source: LoadSource) -> LoadBanner {
        LoadBanner(message: defaultMessage(category, source), retryTargets: [source])
    }

    // MARK: - Exhaustive expectations (no default: a new error case must fail to compile here)

    static func expectedCategory(_ error: ListError) -> LoadFailureCategory {
        switch error {
        case .network: return .unreachable
        case .server, .invalidResponse: return .server
        case .rateLimited: return .rateLimited
        case .forbidden: return .forbidden
        case .notFound: return .notFound
        case .sessionEnded, .unauthorized: return .sessionEnded
        case .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly, .validation,
             .memberEmailNotFound, .alreadyMember, .membershipNotFound:
            return .other
        }
    }

    static func expectedCategory(_ error: ItemError) -> LoadFailureCategory {
        switch error {
        case .network: return .unreachable
        case .server, .invalidResponse: return .server
        case .rateLimited: return .rateLimited
        case .forbidden: return .forbidden
        case .notFound: return .notFound
        case .sessionEnded, .unauthorized: return .sessionEnded
        case .validation, .invalidPrice, .cannotDeleteWithPurchases: return .other
        }
    }

    static func expectedCategory(_ error: ChildError) -> LoadFailureCategory {
        switch error {
        case .network: return .unreachable
        case .server, .invalidResponse: return .server
        case .rateLimited: return .rateLimited
        case .forbidden: return .forbidden
        case .childNotFound: return .notFound
        case .sessionEnded, .unauthorized: return .sessionEnded
        case .childHasLists, .validation: return .other
        }
    }

    static func expectedCategory(_ error: BudgetError) -> LoadFailureCategory {
        switch error {
        case .network: return .unreachable
        case .server, .invalidResponse: return .server
        case .rateLimited: return .rateLimited
        case .forbidden: return .forbidden
        case .notFound: return .notFound
        case .sessionEnded, .unauthorized: return .sessionEnded
        case .validation, .alreadyExists, .sumExceedsTotal, .hasPurchases: return .other
        }
    }

    // MARK: - Every case of each enum (representative associated values)

    static let allListErrors: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "fake validation"), .rateLimited(retryAfter: 30), .unauthorized,
        .sessionEnded, .network, .invalidResponse, .server, .memberEmailNotFound, .alreadyMember,
        .membershipNotFound
    ]

    static let allItemErrors: [ItemError] = [
        .notFound, .unauthorized, .forbidden, .validation(message: "fake validation"), .invalidPrice,
        .cannotDeleteWithPurchases, .rateLimited(retryAfter: 30), .sessionEnded, .network,
        .invalidResponse, .server
    ]

    static let allChildErrors: [ChildError] = [
        .childNotFound, .childHasLists, .validation(message: "fake validation"),
        .rateLimited(retryAfter: 30), .unauthorized, .sessionEnded, .network, .invalidResponse,
        .server, .forbidden
    ]

    static let allBudgetErrors: [BudgetError] = [
        .notFound, .unauthorized, .forbidden, .validation(message: "fake validation"),
        .alreadyExists(message: "fake exists"), .sumExceedsTotal(message: "fake sum"),
        .hasPurchases(message: "fake purchases"), .rateLimited(retryAfter: 30), .sessionEnded,
        .network, .invalidResponse, .server
    ]
}
