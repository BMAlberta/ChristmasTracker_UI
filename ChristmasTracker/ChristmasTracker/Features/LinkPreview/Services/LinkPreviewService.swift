//
//  LinkPreviewService.swift
//  ChristmasTracker
//
//  Session-safe service that asks the API for the product image of a page URL. It holds no state
//  besides the session bookkeeping: the result goes straight back to the caller. An invalid page URL
//  makes no call, the result passes LinkPreviewImageFilter, and every failure, cancellation or
//  session end is nil. Neither the page URL nor the image value is ever logged, reported or put in a
//  span.
//

import Foundation
import Observation
import Sentry

@MainActor
@Observable
final class LinkPreviewService {

    // MARK: - Dependencies

    private nonisolated let repository: any LinkPreviewLoading
    private nonisolated let provider: any ProductImageProviding
    private nonisolated let log: ServiceLog

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result if it changed.
    private var generation = 0

    /// Read-only view of the session generation.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    // MARK: - Initialization

    init(
        repository: any LinkPreviewLoading,
        provider: any ProductImageProviding = InertProductImageProvider(),
        log: ServiceLog = ServiceLog()
    ) {
        self.repository = repository
        self.provider = provider
        self.log = log
    }

    // MARK: - Lookup

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so the
    // InstrumentedOperation span is used (the helper works on the main actor). Neither the URL, its
    // host nor the image value goes into the span or a line; the lines carry the operation name only.
    /// The accepted image URL for `pageURL`, or nil for an invalid page URL, no image, any failure,
    /// a cancelled caller or an ended session. An invalid page URL makes no call and logs nothing.
    func imageUrl(for pageURL: String) async -> String? {
        guard let page = LinkPreviewInput.validated(pageURL) else { return nil }

        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        return try? await InstrumentedOperation.run("service.linkPreview.imageUrl") { () async -> String? in
            // The two calls are two operations: the API lookup (`op`) and the device fallback (`opName`).
            let op = "link preview lookup"
            let opName = "device link preview"
            let gen = generation
            let repository = self.repository
            let provider = self.provider

            // Step 1: the API. A cancellation ends the lookup; any other error counts as "no image".
            var apiValue: String?
            var apiFailed = false
            log.started(op)
            do {
                apiValue = try await perform { try await repository.imageUrl(for: page) }
            } catch {
                if error is CancellationError || gen != generation || Task.isCancelled {
                    log.cancelled(op)
                    return nil
                }
                log.failed(op)
                apiFailed = true
                apiValue = nil
            }
            if gen != generation || Task.isCancelled {
                log.cancelled(op)
                return nil
            }
            if !apiFailed { log.processed(op) }
            if let accepted = LinkPreviewImageFilter.accepted(apiValue) { return accepted }

            // Step 2: the device, only for a live task in the same session.
            log.started(opName)
            do {
                let raw = try await perform { try await provider.imageUrl(for: page) }
                if gen != generation || Task.isCancelled {
                    log.cancelled(opName)
                    return nil
                }
                log.processed(opName)
                return LinkPreviewImageFilter.accepted(ProductImageURLNormalizer.normalized(raw))
            } catch {
                if error is CancellationError || gen != generation || Task.isCancelled {
                    log.cancelled(opName)
                } else {
                    log.failed(opName)
                }
                return nil
            }
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls and bumps the generation so late
    /// results are discarded.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied here, so a manual span is used (no
    // repository call, so no step lines). No data goes into the span.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.linkPreview.clearForSession",
            operation: "service.linkPreview.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }
    }

    // MARK: - Private Functions

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Actor-isolated (@MainActor) exception: a private helper on a @MainActor service, so
    // @Instrumented cannot apply to it. Covered by the InstrumentedOperation span of its public caller (imageUrl).
    private func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task { try await work() }
        let handle = UUID()
        inFlight[handle] = { task.cancel() }
        defer { inFlight[handle] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

// MARK: - SessionClearable

extension LinkPreviewService: SessionClearable {}
