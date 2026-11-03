//
//  SentryBootstrap.swift
//  ChristmasTracker
//

import Foundation
import Sentry

enum SentryBootstrap {

    /// Builds Sentry options for the given DSN, environment, and release identifier.
    /// Returns nil when dsn is empty or blank — caller must not start the SDK in that case.
    nonisolated static func makeOptions(
        dsn: String,
        environment: String,
        release: String
    ) -> Options? {
        let trimmed = dsn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let options = Options()
        options.dsn = trimmed
        options.environment = environment
        options.releaseName = release
        options.sendDefaultPii = false
        options.attachScreenshot = false
        options.attachViewHierarchy = false
        options.enableNetworkBreadcrumbs = false
        options.enableNetworkTracking = false
        options.enableCaptureFailedRequests = false
        options.enableUserInteractionTracing = false
        options.enableAutoBreadcrumbTracking = false
        options.enableLogs = false
        options.sessionReplay.sessionSampleRate = 0
        options.sessionReplay.onErrorSampleRate = 0
        options.enableMetricKit = false
        options.tracesSampleRate = 0.05
        options.beforeSend = { event in scrubEvent(event) }
        options.beforeBreadcrumb = { crumb in scrubBreadcrumb(crumb) }
        options.beforeSendSpan = { span in
            if let desc = span.spanDescription {
                span.spanDescription = PIIFilter.redact(desc)
            }
            for (key, value) in span.data {
                if let strValue = value as? String {
                    span.setData(value: PIIFilter.redact(strValue), key: key)
                }
            }
            return span
        }
        return options
    }

    /// Scrubs PII from a Sentry event. Returns the modified event; never drops events.
    nonisolated static func scrubEvent(_ event: Event) -> Event {
        if let msg = event.message {
            event.message = SentryMessage(formatted: PIIFilter.redact(msg.formatted))
        }
        event.exceptions?.forEach { exc in
            if let v = exc.value { exc.value = PIIFilter.redact(v) }
        }
        if let extra = event.extra {
            var cleaned: [String: Any] = [:]
            for (key, value) in extra {
                cleaned[key] = PIIFilter.redact("\(value)")
            }
            event.extra = cleaned
        }
        if let tags = event.tags {
            event.tags = tags.mapValues { PIIFilter.redact($0) }
        }
        if let qs = event.request?.queryString {
            event.request?.queryString = PIIFilter.redact(qs)
        }
        if let url = event.request?.url {
            event.request?.url = PIIFilter.redact(url)
        }
        event.user = nil
        event.serverName = nil
        return event
    }

    /// Scrubs PII from a breadcrumb.
    /// Returns nil for touch and ui.lifecycle breadcrumbs (may contain screen/widget names).
    /// Returns the scrubbed breadcrumb for all other categories.
    nonisolated static func scrubBreadcrumb(_ crumb: Breadcrumb) -> Breadcrumb? {
        guard crumb.category != "touch" && crumb.category != "ui.lifecycle" else { return nil }
        if let msg = crumb.message { crumb.message = PIIFilter.redact(msg) }
        if let data = crumb.data {
            var cleaned: [String: Any] = [:]
            for (key, value) in data {
                cleaned[key] = PIIFilter.redact("\(value)")
            }
            crumb.data = cleaned
        }
        return crumb
    }

    /// Starts Sentry when a non-empty DSN is configured.
    /// Logs whether Sentry is enabled (never logs the DSN itself).
    /// Called as the first statement of ChristmasTrackerApp.init.
    static func startIfConfigured() {
        let dsn = AppConfiguration.sentryDSN ?? ""
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let release = "com.alberta.ChristmasTracker@\(marketing)+\(build)"

        guard let options = makeOptions(
            dsn: dsn,
            environment: AppConfiguration.appEnvironment,
            release: release
        ) else {
            LogInfo("Sentry disabled (no DSN configured)", category: .business)
            return
        }
        SentrySDK.start(options: options)
        LogInfo("Sentry enabled for environment: \(AppConfiguration.appEnvironment)", category: .business)
    }
}
