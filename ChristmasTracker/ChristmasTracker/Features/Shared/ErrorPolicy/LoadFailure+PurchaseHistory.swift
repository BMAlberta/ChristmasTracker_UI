//
//  LoadFailure+PurchaseHistory.swift
//  ChristmasTracker
//
//  PH1: classifies a PurchaseHistoryError as a load failure. Exhaustive switch with no default, so a
//  new case fails to compile until it is categorised.
//

import Foundation

extension LoadFailure {
    init(_ error: PurchaseHistoryError, source: LoadSource) {
        let message = error.userMessage
        switch error {
        case .network:
            self.init(category: .unreachable, source: source, plainMessage: message)
        case .server, .invalidResponse:
            self.init(category: .server, source: source, plainMessage: message)
        case .rateLimited(let seconds):
            self.init(
                category: .rateLimited, source: source,
                retryAfter: Self.historyWholeSeconds(seconds), plainMessage: message
            )
        case .forbidden:
            self.init(category: .forbidden, source: source, plainMessage: message)
        case .notFound:
            self.init(category: .notFound, source: source, plainMessage: message)
        case .sessionEnded, .unauthorized:
            self.init(category: .sessionEnded, source: source, plainMessage: message)
        case .validation:
            self.init(category: .other, source: source, plainMessage: message)
        }
    }

    private static func historyWholeSeconds(_ seconds: TimeInterval) -> Int? {
        guard seconds.isFinite, seconds >= 1 else { return nil }
        return Int(min(seconds.rounded(.up), Double(maxRetryAfter)))
    }
}
