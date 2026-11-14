//
//  LoadFailure.swift
//  ChristmasTracker
//
//  UX1a Story U1: a classified load failure. Every typed error case is mapped deliberately by an
//  exhaustive switch with no default, so a new case fails to compile until it is categorised.
//

import Foundation

nonisolated struct LoadFailure: Sendable, Equatable {
    let category: LoadFailureCategory
    let source: LoadSource
    /// Whole seconds (rounded up, capped at `maxRetryAfter`); nil when unusable.
    let retryAfter: Int?
    /// The typed error's `userMessage`, kept so rate-limit hints and server text survive.
    let plainMessage: String

    static let maxRetryAfter = 3600

    init(category: LoadFailureCategory, source: LoadSource, retryAfter: Int? = nil, plainMessage: String) {
        self.category = category
        self.source = source
        self.retryAfter = retryAfter
        self.plainMessage = plainMessage
    }

    init(_ error: ListError, source: LoadSource) {
        switch error {
        case .network:
            self.init(.unreachable, source, error.userMessage)
        case .server, .invalidResponse:
            self.init(.server, source, error.userMessage)
        case .rateLimited(let seconds):
            self.init(.rateLimited, source, error.userMessage, Self.wholeSeconds(seconds))
        case .forbidden:
            self.init(.forbidden, source, error.userMessage)
        case .notFound:
            self.init(.notFound, source, error.userMessage)
        case .sessionEnded, .unauthorized:
            self.init(.sessionEnded, source, error.userMessage)
        case .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly, .validation,
             .memberEmailNotFound, .alreadyMember, .membershipNotFound:
            self.init(.other, source, error.userMessage)
        }
    }

    init(_ error: ItemError, source: LoadSource) {
        switch error {
        case .network:
            self.init(.unreachable, source, error.userMessage)
        case .server, .invalidResponse:
            self.init(.server, source, error.userMessage)
        case .rateLimited(let seconds):
            self.init(.rateLimited, source, error.userMessage, Self.wholeSeconds(seconds))
        case .forbidden:
            self.init(.forbidden, source, error.userMessage)
        case .notFound:
            self.init(.notFound, source, error.userMessage)
        case .sessionEnded, .unauthorized:
            self.init(.sessionEnded, source, error.userMessage)
        case .validation, .invalidPrice, .cannotDeleteWithPurchases:
            self.init(.other, source, error.userMessage)
        }
    }

    init(_ error: ChildError, source: LoadSource) {
        switch error {
        case .network:
            self.init(.unreachable, source, error.userMessage)
        case .server, .invalidResponse:
            self.init(.server, source, error.userMessage)
        case .rateLimited(let seconds):
            self.init(.rateLimited, source, error.userMessage, Self.wholeSeconds(seconds))
        case .forbidden:
            self.init(.forbidden, source, error.userMessage)
        case .childNotFound:
            self.init(.notFound, source, error.userMessage)
        case .sessionEnded, .unauthorized:
            self.init(.sessionEnded, source, error.userMessage)
        case .childHasLists, .validation:
            self.init(.other, source, error.userMessage)
        }
    }

    init(_ error: BudgetError, source: LoadSource) {
        switch error {
        case .network:
            self.init(.unreachable, source, error.userMessage)
        case .server, .invalidResponse:
            self.init(.server, source, error.userMessage)
        case .rateLimited(let seconds):
            self.init(.rateLimited, source, error.userMessage, Self.wholeSeconds(seconds))
        case .forbidden:
            self.init(.forbidden, source, error.userMessage)
        case .notFound:
            self.init(.notFound, source, error.userMessage)
        case .sessionEnded, .unauthorized:
            self.init(.sessionEnded, source, error.userMessage)
        case .validation, .alreadyExists, .sumExceedsTotal, .hasPurchases:
            self.init(.other, source, error.userMessage)
        }
    }

    private init(
        _ category: LoadFailureCategory,
        _ source: LoadSource,
        _ message: String,
        _ retryAfter: Int? = nil
    ) {
        self.init(category: category, source: source, retryAfter: retryAfter, plainMessage: message)
    }

    private static func wholeSeconds(_ seconds: TimeInterval) -> Int? {
        guard seconds.isFinite, seconds >= 1 else { return nil }
        return Int(min(seconds.rounded(.up), Double(maxRetryAfter)))
    }
}
