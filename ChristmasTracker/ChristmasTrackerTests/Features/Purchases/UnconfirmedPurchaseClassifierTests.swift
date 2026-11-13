//
//  UnconfirmedPurchaseClassifierTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the pure classification of a record request that got NO HTTP response.
//  Definitive: the request certainly was not delivered. Unconfirmed: the server may have recorded
//  the purchase, and every code not listed defaults to unconfirmed. `cancelled` is not classified
//  (the repository turns it into a cancellation before the classifier) and is not asserted here.
//
//  Fails today because UnconfirmedPurchaseClassifier and PurchaseFailureKind do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum ClassifierFixtures {
    static let definitive: [URLError.Code] = [
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet,
        .secureConnectionFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive,
        .badURL, .unsupportedURL, .appTransportSecurityRequiresSecureConnection,
        .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired
    ]

    static let unconfirmed: [URLError.Code] = [
        .timedOut, .networkConnectionLost, .badServerResponse, .cannotParseResponse,
        .zeroByteResource, .cannotDecodeRawData, .cannotDecodeContentData, .httpTooManyRedirects,
        .redirectToNonExistentLocation
    ]

    /// Codes in neither list (and not `cancelled`): they default to unconfirmed.
    static let unlisted: [URLError.Code] = [
        .userAuthenticationRequired, .resourceUnavailable, .fileDoesNotExist, .downloadDecodingFailedMidStream,
        .backgroundSessionWasDisconnected, .requestBodyStreamExhausted, .unknown,
        URLError.Code(rawValue: 987_654), URLError.Code(rawValue: -123_456)
    ]
}

@Suite("Unconfirmed purchase classifier Tests")
struct UnconfirmedPurchaseClassifierTests {

    private func makeSUT(_ code: URLError.Code) -> PurchaseFailureKind {
        UnconfirmedPurchaseClassifier.kind(forURLErrorCode: code)
    }

    @Test("Codes where the request was certainly not delivered are definitive",
          arguments: ClassifierFixtures.definitive)
    func definitive(code: URLError.Code) {
        #expect(makeSUT(code) == .definitive, "\(code.rawValue)")
    }

    @Test("Codes where the server may have recorded the purchase are unconfirmed",
          arguments: ClassifierFixtures.unconfirmed)
    func unconfirmed(code: URLError.Code) {
        #expect(makeSUT(code) == .unconfirmed, "\(code.rawValue)")
    }

    @Test("Every code not listed, including an unknown raw code, defaults to unconfirmed",
          arguments: ClassifierFixtures.unlisted)
    func unlistedDefaultsToUnconfirmed(code: URLError.Code) {
        #expect(makeSUT(code) == .unconfirmed, "\(code.rawValue)")
    }

    @Test("The definitive and unconfirmed lists do not overlap")
    func listsAreDisjoint() {
        let definitive = Set(ClassifierFixtures.definitive.map(\.rawValue))
        let unconfirmed = Set(ClassifierFixtures.unconfirmed.map(\.rawValue))
        #expect(definitive.isDisjoint(with: unconfirmed))
    }
}
