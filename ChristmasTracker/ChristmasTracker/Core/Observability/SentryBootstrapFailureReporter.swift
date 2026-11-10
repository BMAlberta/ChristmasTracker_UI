//
//  SentryBootstrapFailureReporter.swift
//  ChristmasTracker
//
//  Production BootstrapFailureReporting: one Sentry event with an error category only. No URL,
//  no value, no error description. Sentry's beforeSend scrubbing (SentryBootstrap) still applies.
//  When Sentry was not started (no DSN) the capture is a no-op.
//

import Foundation
import Sentry

final class SentryBootstrapFailureReporter: BootstrapFailureReporting {
    func reportClientUnavailable(category: String) {
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: "Bootstrap failed")
        event.tags = ["error_category": category]
        SentrySDK.capture(event: event)
    }
}
