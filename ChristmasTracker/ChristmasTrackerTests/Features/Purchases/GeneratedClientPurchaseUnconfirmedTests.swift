//
//  GeneratedClientPurchaseUnconfirmedTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: the unconfirmed-purchase rules of the RECORD path (GeneratedClientPurchaseRepository),
//  through the REAL factory-built client with a fake transport (Gate 1 Story B interface item 3).
//
//  Rules under test:
//   - a URLError without a response is classified with UnconfirmedPurchaseClassifier: definitive
//     gives `.network`, unconfirmed gives `.unconfirmed`, an unlisted code is unconfirmed, and
//     `.cancelled` stays a CancellationError;
//   - any error while reading or mapping the body of a 201 is `.unconfirmed` (the purchase exists);
//   - a body that cannot be read on a 200 (a confirmation_required included) stays `.invalidResponse`;
//   - every HTTP error with a response keeps today's mapping (a 500 is definitive `.server`);
//   - SessionRefreshError stays `.network`; TrackerAPIError.invalidServerURL stays `.invalidResponse`.
//
//  Not reachable through the real client: the "unknown error thrown outside the client" fallback
//  (a transport error is always wrapped in a ClientError by the runtime), so that one line of the
//  spec has no test here.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseRepository unconfirmed rules", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseUnconfirmedTests {

    // MARK: URLError classification (the table in the classifier)

    nonisolated static let definitiveCodes: [URLError.Code] = [
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet,
        .secureConnectionFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive,
        .badURL, .unsupportedURL, .appTransportSecurityRequiresSecureConnection,
        .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired
    ]

    nonisolated static let unconfirmedCodes: [URLError.Code] = [
        .timedOut, .networkConnectionLost, .badServerResponse, .cannotParseResponse, .zeroByteResource,
        .cannotDecodeRawData, .cannotDecodeContentData, .httpTooManyRedirects, .redirectToNonExistentLocation
    ]

    /// Codes the classifier table does not list: they default to unconfirmed.
    nonisolated static let unlistedCodes: [URLError.Code] = [
        .fileDoesNotExist, .resourceUnavailable, .userCancelledAuthentication,
        .requestBodyStreamExhausted, .backgroundSessionWasDisconnected, .unknown,
        URLError.Code(rawValue: -99_999)
    ]

    @Test("a definitive URLError (the request was certainly not delivered) throws network",
          arguments: definitiveCodes)
    func definitiveFailureIsNetwork(code: URLError.Code) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: PurchaseError.network) {
            _ = try await sut.create()
        }
    }

    @Test("an unconfirmed URLError (the server may have recorded the purchase) throws unconfirmed",
          arguments: unconfirmedCodes)
    func unconfirmedFailure(code: URLError.Code) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    @Test("a URLError code the table does not list defaults to unconfirmed", arguments: unlistedCodes)
    func unlistedCodeIsUnconfirmed(code: URLError.Code) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    @Test("the repository and the classifier agree for every code in the table",
          arguments: definitiveCodes + unconfirmedCodes + unlistedCodes)
    func repositoryFollowsTheClassifier(code: URLError.Code) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(code))
        let expected: PurchaseError = UnconfirmedPurchaseClassifier.kind(forURLErrorCode: code) == .definitive
            ? .network : .unconfirmed

        let thrown = await captureRecordError { _ = try await sut.create() }

        #expect(thrown == expected, "code \(code.rawValue)")
    }

    @Test("a URLError.cancelled stays a CancellationError, never network or unconfirmed")
    func cancelledStaysACancellation() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.create()
        }
    }

    @Test("an unconfirmed failure on a confirmed resubmit (with a token) is also unconfirmed")
    func unconfirmedOnResubmit() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.timedOut))

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create(token: PurchaseWire.token)
        }
    }

    @Test("a definitive failure on a confirmed resubmit (with a token) is network")
    func definitiveOnResubmit() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))

        await #expect(throws: PurchaseError.network) {
            _ = try await sut.create(token: PurchaseWire.token)
        }
    }

    @Test("an unconfirmed failure sent exactly one request: the repository never retries by itself")
    func noAutomaticRetry() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.networkConnectionLost))

        _ = await captureRecordError { _ = try await sut.create() }

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: A 201 whose body cannot be read

    @Test("a 201 whose body cannot be read or mapped is unconfirmed: the purchase exists on the server",
          arguments: [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": { \"status\": \"created\" }, \"meta\": \(ListWire.metaJSON) }",
        PurchaseWire.createdEnvelope(purchase: "{ \"id\": \"purchase-1\", \"itemId\": \"item-1\" }"),
        PurchaseWire.createdEnvelope(purchase: PurchaseWire.purchaseJSON(shippingStatus: "TELEPORTED")),
        PurchaseWire.confirmationInCreatedEnvelope(warnings: [PurchaseWire.warningJSON()])
    ])
    func unreadableCreatedBody(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: body)

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    @Test("a 201 with no body at all is unconfirmed")
    func emptyCreatedBody() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueEmpty(status: 201)

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    @Test("a 201 whose body cannot be read is unconfirmed on a confirmed resubmit too")
    func unreadableCreatedBodyOnResubmit() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: "{ this is not json")

        await #expect(throws: PurchaseError.unconfirmed) {
            _ = try await sut.create(token: PurchaseWire.token)
        }
    }

    @Test("a readable 201 is still a created purchase")
    func readableCreatedBodyIsCreated() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope())

        let outcome = try await sut.create()

        guard case .created = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
    }

    // MARK: A 200 whose body cannot be read

    @Test("a 200 whose body cannot be read stays invalidResponse, never unconfirmed",
          arguments: [
        "{ this is not json",
        "{ \"success\": true }",
        PurchaseWire.confirmationEnvelope(warnings: []),
        PurchaseWire.confirmationEnvelope(warnings: [PurchaseWire.warningJSON(token: "")])
    ])
    func unreadableOkBody(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 200, json: body)

        await #expect(throws: PurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    @Test("a 200 with no body at all stays invalidResponse")
    func emptyOkBody() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueEmpty(status: 200)

        await #expect(throws: PurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    // MARK: HTTP errors with a response stay definitive

    @Test("a 500 is a definitive server error, never unconfirmed")
    func serverErrorIsDefinitive() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)

        await #expect(throws: PurchaseError.server) {
            _ = try await sut.create()
        }
    }

    @Test("HTTP errors with a response keep their mapping and are never unconfirmed", arguments: [
        (400, PurchaseWire.validationError, PurchaseError.validation(message: "Store name must be at most 200 characters")),
        (403, PurchaseWire.forbidden, PurchaseError.forbidden),
        (404, PurchaseWire.itemNotFound, PurchaseError.notFound),
        (502, ListWire.internalError, PurchaseError.server),
        (418, ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot"), PurchaseError.invalidResponse)
    ])
    func httpErrorsStayDefinitive(row: (Int, String, PurchaseError)) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: row.0, json: row.1)

        let thrown = await captureRecordError { _ = try await sut.create() }

        #expect(thrown == row.2, "status \(row.0)")
        #expect(thrown != .unconfirmed)
    }

    // MARK: Stays as it was

    @Test("a refresh that fails for a non-credential reason stays network, even for a timeout")
    func refreshFailureStaysNetwork() async throws {
        let sut = try makePurchaseRepoSUT(refreshFailure: SessionRefreshError.other(URLError(.timedOut)))
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        let thrown = await captureRecordError { _ = try await sut.create() }

        #expect(thrown == .network)
    }

    @Test("a thrown TrackerAPIError.invalidServerURL stays invalidResponse")
    func invalidServerURLStaysInvalidResponse() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.invalidServerURL)

        await #expect(throws: PurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    @Test("a thrown CancellationError stays a CancellationError")
    func cancellationStaysACancellation() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.create()
        }
    }

    // MARK: Helper

    private func captureRecordError(_ body: () async throws -> Void) async -> PurchaseError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? PurchaseError
        }
    }
}
