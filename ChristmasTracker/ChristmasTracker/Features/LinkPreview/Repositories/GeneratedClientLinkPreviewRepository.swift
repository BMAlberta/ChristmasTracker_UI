//
//  GeneratedClientLinkPreviewRepository.swift
//  ChristmasTracker
//
//  Repository for getLinkPreview on the generated TrackerAPI client. Every documented response is
//  handled explicitly (no default case). A 200 returns its imageUrl (nil when null or absent); every
//  other outcome (400, 401, 403, 404, 429, 500, undocumented, transport error, undecodable body) is
//  nil, because the caller treats all of them as "no image from the API". Only cancellation is
//  thrown. Nothing is logged: neither the page URL nor the image URL ever reaches a log.
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

nonisolated final class GeneratedClientLinkPreviewRepository: LinkPreviewLoading, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func imageUrl(for pageURL: String) async throws -> String? {
        do {
            let input = Operations.GetLinkPreview.Input(body: .json(.init(url: pageURL)))
            let output = try await client.getLinkPreview(input)
            switch output {
            case .ok(let response):
                return try response.body.json.data.imageUrl
            case .badRequest, .unauthorized, .forbidden, .notFound, .tooManyRequests, .internalServerError:
                return nil
            case .undocumented:
                return nil
            }
        } catch {
            if linkPreviewIsCancellation(error) { throw CancellationError() }
            return nil
        }
    }
}

/// True for a cancellation, bare or wrapped by the OpenAPI runtime's `ClientError`.
nonisolated private func linkPreviewIsCancellation(_ error: any Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError { return urlError.code == .cancelled }
    if let clientError = error as? ClientError {
        let cause = clientError.underlyingError
        if cause is CancellationError { return true }
        if let urlError = cause as? URLError { return urlError.code == .cancelled }
    }
    return false
}
