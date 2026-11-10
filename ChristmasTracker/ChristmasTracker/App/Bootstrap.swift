//
//  Bootstrap.swift
//  ChristmasTracker
//
//  The pure decision about whether the app can start against its server, and the state of the
//  blocking configuration-error screen. In real mode without a generated client the app never
//  falls back to mock data: it shows ConfigurationErrorView and nothing else.
//

import Foundation

// MARK: - BootstrapState

nonisolated enum BootstrapState: Equatable, Sendable {
    case ready
    case failed
}

/// Mock mode is always ready. Real mode is ready only when the generated client was built.
nonisolated func resolveBootstrap(mode: APIMode, clientAvailable: Bool) -> BootstrapState {
    switch mode {
    case .mock:
        return .ready
    case .real:
        return clientAvailable ? .ready : .failed
    }
}

// MARK: - ConfigurationError

/// Thrown by the inert repositories built when the generated client is unavailable.
nonisolated enum ConfigurationError: Error, Equatable, Sendable {
    case clientUnavailable
}

// MARK: - BootstrapFailureReporting

/// Reports a bootstrap failure. The category is a constant name; no URL, value or error text.
protocol BootstrapFailureReporting: AnyObject {
    func reportClientUnavailable(category: String)
}

// MARK: - ConfigurationErrorState

/// What the blocking configuration-error screen shows: one fixed message and no action.
nonisolated struct ConfigurationErrorState: Equatable, Sendable {
    static let message = "This version can't connect to the server. Please reinstall the latest version."

    let showsSignIn: Bool
    let showsAnyAction: Bool
    let accessibilityLabel: String

    /// The screen state for a bootstrap result, or nil when the app is ready.
    static func state(for bootstrap: BootstrapState) -> ConfigurationErrorState? {
        switch bootstrap {
        case .ready:
            return nil
        case .failed:
            return ConfigurationErrorState(
                showsSignIn: false,
                showsAnyAction: false,
                accessibilityLabel: "Connection problem. \(message)"
            )
        }
    }
}
