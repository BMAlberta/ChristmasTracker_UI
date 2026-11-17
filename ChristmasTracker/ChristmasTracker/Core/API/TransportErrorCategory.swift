//
//  TransportErrorCategory.swift
//  ChristmasTracker
//
//  Maps a transport error to a fixed category string for the log. A pure function of the error
//  type and URLError.Code; it never reads a description, message or user info, which can carry
//  the URL.
//

import Foundation

nonisolated enum TransportErrorCategory {
    /// Cancellation is logged separately from failures.
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError { return urlError.code == .cancelled }
        return false
    }

    /// One of: timeout, offline, dns, tls, other.
    static func category(for error: any Error) -> String {
        guard let urlError = error as? URLError else { return "other" }
        switch urlError.code {
        case .timedOut:
            return "timeout"
        case .notConnectedToInternet, .networkConnectionLost:
            return "offline"
        case .cannotFindHost, .dnsLookupFailed:
            return "dns"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired:
            return "tls"
        default:
            return "other"
        }
    }
}
