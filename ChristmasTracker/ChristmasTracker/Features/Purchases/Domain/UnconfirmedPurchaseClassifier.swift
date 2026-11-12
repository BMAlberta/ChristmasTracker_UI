//
//  UnconfirmedPurchaseClassifier.swift
//  ChristmasTracker
//
//  Classifies a record request that got no HTTP response. Definitive: the request certainly was
//  not delivered. Unconfirmed: the server may have recorded the purchase. Every code not listed
//  is unconfirmed. `cancelled` is a cancellation handled before this runs.
//

import Foundation

nonisolated enum PurchaseFailureKind: Equatable, Sendable {
    case definitive
    case unconfirmed
}

nonisolated enum UnconfirmedPurchaseClassifier {
    static func kind(forURLErrorCode code: URLError.Code) -> PurchaseFailureKind {
        switch code {
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet,
             .secureConnectionFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive,
             .badURL, .unsupportedURL, .appTransportSecurityRequiresSecureConnection,
             .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
            return .definitive
        default:
            return .unconfirmed
        }
    }
}
