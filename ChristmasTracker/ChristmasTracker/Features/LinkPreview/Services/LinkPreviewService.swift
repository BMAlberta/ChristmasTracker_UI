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

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result if it changed.
    private var generation = 0

    /// Read-only view of the session generation.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    // MARK: - Initialization

    init(repository: any LinkPreviewLoading) {
        self.repository = repository
    }

    // MARK: - Lookup

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so a
    // manual SentrySDK span is used. No URL or value goes into the span.
    /// The accepted image URL for `pageURL`, or nil for an invalid page URL, no image, any failure,
    /// a cancelled caller or an ended session.
    func imageUrl(for pageURL: String) async -> String? {
        guard let page = LinkPreviewInput.validated(pageURL) else { return nil }

        let span = SentrySDK.startTransaction(
            name: "service.linkPreview.imageUrl",
            operation: "service.linkPreview.imageUrl"
        )
        defer { span.finish() }

        let gen = generation
        do {
            let repository = self.repository
            let raw = try await perform { try await repository.imageUrl(for: page) }
            if gen != generation || Task.isCancelled { return nil }
            return LinkPreviewImageFilter.accepted(raw)
        } catch {
            return nil
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls and bumps the generation so late
    /// results are discarded.
    // Actor-isolated (@MainActor): manual SentrySDK span, see imageUrl.
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
    // @Instrumented cannot apply to it. Covered by the manual span of its public caller (imageUrl).
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
