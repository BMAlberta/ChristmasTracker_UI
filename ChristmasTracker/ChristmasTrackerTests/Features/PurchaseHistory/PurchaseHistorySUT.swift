//
//  PurchaseHistorySUT.swift
//  ChristmasTrackerTests
//
//  PH1-H1: the REAL `TrackerClientFactory.make` client around the recording fake transport
//  (`ListFakeTransport`), wrapped by the repository under test. No network, no Keychain.
//
//  Construction (Gate 1 interface):
//      GeneratedClientPurchaseHistoryRepository(client: client)
//

import Foundation
import HTTPTypes
import TrackerAPI
@testable import ChristmasTracker

let purchaseHistoryAccessToken = "tok-access-FAKE"

private let purchaseHistoryBaseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()

enum PurchaseHistorySUTError: Error {
    case noRequest
}

struct PurchaseHistorySUT {
    let repo: GeneratedClientPurchaseHistoryRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher

    func load(_ filter: PurchaseHistoryFilter = PurchaseHistoryFilter(), cursor: String? = nil) async throws -> PurchaseHistoryPage {
        try await repo.loadPage(filter: filter, cursor: cursor)
    }

    /// Runs one call and returns whatever it threw (nil when it returned).
    func thrown(_ filter: PurchaseHistoryFilter = PurchaseHistoryFilter(), cursor: String? = nil) async -> (any Error)? {
        do {
            _ = try await load(filter, cursor: cursor)
            return nil
        } catch {
            return error
        }
    }

    /// Runs one call and returns the PurchaseHistoryError it threw (nil when it threw nothing or something else).
    func historyError() async -> PurchaseHistoryError? {
        await thrown() as? PurchaseHistoryError
    }

    func lastRequest() async throws -> ListFakeTransport.Recorded {
        guard let request = await transport.lastRequest() else {
            throw PurchaseHistorySUTError.noRequest
        }
        return request
    }

    /// The decoded query items of the last request line (empty when there is no query).
    func lastQueryItems() async throws -> [URLQueryItem] {
        let path = try await lastRequest().request.path ?? ""
        return URLComponents(string: "https://api.example.com" + path)?.queryItems ?? []
    }
}

func makePurchaseHistorySUT(
    token: String? = purchaseHistoryAccessToken,
    refreshFailure: (any Error)? = nil
) throws -> PurchaseHistorySUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: purchaseHistoryBaseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return PurchaseHistorySUT(
        repo: GeneratedClientPurchaseHistoryRepository(client: client),
        transport: transport,
        refresher: refresher
    )
}
