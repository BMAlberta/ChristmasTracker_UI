// VersionOutdatedMiddleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct VersionOutdatedMiddleware: ClientMiddleware {
    private let handler: any VersionOutdatedHandling

    public init(handler: any VersionOutdatedHandling) {
        self.handler = handler
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status.code == 426 else {
            return (response, responseBody)
        }

        // Buffer the full body so we can parse it and return it to the caller
        var bufferedData = Data()
        if let responseBody {
            for try await chunk in responseBody {
                bufferedData.append(contentsOf: chunk)
            }
        }

        let details = parseVersionOutdatedDetails(from: bufferedData)
        await handler.handleVersionOutdated(details)

        // Return the 426 response with a rebuilt readable body
        let rebuiltBody = HTTPBody(bufferedData)
        return (response, rebuiltBody)
    }

    private func parseVersionOutdatedDetails(from data: Data) -> VersionOutdatedDetails {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VersionOutdatedDetails(
                minimumVersion: "",
                minimumBuild: nil,
                latestVersion: nil,
                latestBuild: nil,
                manifestUrl: nil,
                ipaUrl: nil
            )
        }

        // Try nested structure: error.details (from API error envelope)
        if let errorObj = json["error"] as? [String: Any],
           let details = errorObj["details"] as? [String: Any] {
            return makeDetails(from: details)
        }

        // Try flat structure (direct VersionOutdatedDetails object)
        return makeDetails(from: json)
    }

    private func makeDetails(from dict: [String: Any]) -> VersionOutdatedDetails {
        VersionOutdatedDetails(
            minimumVersion: dict["minimumVersion"] as? String ?? "",
            minimumBuild: dict["minimumBuild"] as? Int,
            latestVersion: dict["latestVersion"] as? String,
            latestBuild: dict["latestBuild"] as? Int,
            manifestUrl: dict["manifestUrl"] as? String,
            ipaUrl: dict["ipaUrl"] as? String
        )
    }
}
