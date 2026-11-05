// RateLimitMiddleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

private let maxRetries = 2
private let maxSingleWait: TimeInterval = 10
private let maxTotalWait: TimeInterval = 20
private let retryAfterHeader: HTTPField.Name = {
    guard let n = HTTPField.Name("Retry-After") else {
        preconditionFailure("Retry-After is not a valid HTTP header field name")
    }
    return n
}()

/// Parses a 429 body to extract error.details.retryAfter
private func parseRetryAfter(from body: HTTPBody?) async -> TimeInterval? {
    guard let body else { return nil }
    do {
        var data = Data()
        for try await chunk in body {
            data.append(contentsOf: chunk)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = json?["error"] as? [String: Any]
        let details = error?["details"] as? [String: Any]
        if let retryAfter = details?["retryAfter"] as? TimeInterval {
            return retryAfter
        }
    } catch {}
    return nil
}

private func retryAfterFromHeader(_ response: HTTPResponse) -> TimeInterval? {
    guard let value = response.headerFields[retryAfterHeader] else { return nil }
    return TimeInterval(value)
}

public struct RateLimitMiddleware: ClientMiddleware {
    private let sleeper: any RateLimitSleeping

    public init(sleeper: any RateLimitSleeping = DefaultSleeper()) {
        self.sleeper = sleeper
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let canRetry = request.method == .get || request.method == .head

        var totalWaited: TimeInterval = 0

        for attempt in 0...maxRetries {
            let (response, responseBody) = try await next(request, body, baseURL)
            guard response.status.code == 429 else {
                return (response, responseBody)
            }

            // Extract retryAfter: JSON body takes priority over header
            var retryAfter = await parseRetryAfter(from: responseBody)
                ?? retryAfterFromHeader(response)
                ?? 1.0
            retryAfter = min(retryAfter, maxSingleWait)

            if !canRetry || attempt == maxRetries || totalWaited + retryAfter > maxTotalWait {
                throw TrackerAPIError.rateLimited(retryAfter: retryAfter)
            }

            await sleeper.sleep(seconds: retryAfter)
            totalWaited += retryAfter
        }

        // Compiler satisfaction — the loop always returns or throws
        throw TrackerAPIError.rateLimited(retryAfter: 1)
    }
}

public struct DefaultSleeper: RateLimitSleeping {
    public init() {}
    public func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
