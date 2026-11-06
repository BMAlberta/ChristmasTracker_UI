// RequestIDSeam.swift — RequestIDObserving implementation.
// @unchecked Sendable: lastRequestID is written only from the observe() async context;
// callers await observe() before reading, so there is no concurrent mutation in practice.
import Foundation
import TrackerAPI
import Sentry

final class RequestIDSeam: RequestIDObserving, @unchecked Sendable {
    private let isSentryEnabled: Bool
    private(set) var lastRequestID: String?

    init(isSentryEnabled: Bool) {
        self.isSentryEnabled = isSentryEnabled
    }

    func observe(requestID: String) async {
        lastRequestID = requestID
        guard isSentryEnabled else { return }
        SentrySDK.configureScope { scope in
            scope.setTag(value: requestID, key: "request_id")
        }
    }
}
