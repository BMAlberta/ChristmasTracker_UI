//
//  BiometricOfferAction.swift
//  ChristmasTracker
//
//  Pure types and function for deciding what biometric offer action to take after login.
//

import Foundation

// MARK: - BiometricOfferAction

internal enum BiometricOfferAction: Equatable {
    case none
    case silentlyReplaceToken
    case silentlyReenroll
    case showEnablementScreen
}

// MARK: - biometricOfferAction

/// Pure, nonisolated function that decides what biometric offer action to take after a
/// successful login. Apply rules in precedence order — stop at the first match.
internal nonisolated func biometricOfferAction(
    readiness: BiometricReadiness,
    enrolledUserId: String?,
    signedInUserId: String,
    previouslyEnrolledUserId: String?,
    offerShownForUser: Bool,
    pendingRequest: Bool
) -> BiometricOfferAction {
    // Rule 1: device not ready → nothing to offer
    switch readiness {
    case .ready: break
    case .noHardware, .needsSetup: return .none
    }

    // Rule 2: same user is already enrolled → silently rotate the stored token
    if let enrolledId = enrolledUserId, enrolledId == signedInUserId {
        return .silentlyReplaceToken
    }

    // Rule 3: a different user is enrolled → cannot offer
    if enrolledUserId != nil {
        return .none
    }

    // No enrollment from here on.

    // Rule 4: explicit pending request overrides all suppression flags
    if pendingRequest {
        return .showEnablementScreen
    }

    // Rule 5: user previously enrolled on this device → silently re-enroll
    if previouslyEnrolledUserId == signedInUserId {
        return .silentlyReenroll
    }

    // Rule 6: offer not yet shown to this user → show the enablement screen
    if !offerShownForUser {
        return .showEnablementScreen
    }

    // Rule 7: offer already shown and no other condition applies
    return .none
}

// MARK: - EnrollmentHistoryStoring

internal protocol EnrollmentHistoryStoring: Sendable {
    nonisolated var previouslyEnrolledUserId: String? { get }
    nonisolated func setPreviouslyEnrolledUserId(_ userId: String?)
    nonisolated func hasSeenOffer(for userId: String) -> Bool
    nonisolated func markOfferShown(for userId: String)
}

// MARK: - UserDefaultsEnrollmentHistory

internal struct UserDefaultsEnrollmentHistory: EnrollmentHistoryStoring {

    // nonisolated(unsafe): UserDefaults is internally thread-safe; we only store the reference once.
    nonisolated(unsafe) private let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    nonisolated var previouslyEnrolledUserId: String? {
        defaults.string(forKey: "enrollment.previousUserId")
    }

    nonisolated func setPreviouslyEnrolledUserId(_ userId: String?) {
        defaults.set(userId, forKey: "enrollment.previousUserId")
    }

    nonisolated func hasSeenOffer(for userId: String) -> Bool {
        defaults.bool(forKey: "enrollment.offerShown.\(userId)")
    }

    nonisolated func markOfferShown(for userId: String) {
        defaults.set(true, forKey: "enrollment.offerShown.\(userId)")
    }
}

// MARK: - EphemeralEnrollmentHistory

/// A non-persistent, in-memory EnrollmentHistoryStoring.
///
/// Used as the **default** in `AuthenticationService.init()` so that every test instance that
/// does not explicitly supply an `enrollmentHistory` gets a fresh, isolated store. This prevents
/// cross-test UserDefaults contamination.
///
/// Production code (`ChristmasTrackerApp`) must pass `UserDefaultsEnrollmentHistory()` explicitly
/// so that enrollment history is persisted across app launches.
internal final class EphemeralEnrollmentHistory: EnrollmentHistoryStoring, @unchecked Sendable {

    nonisolated(unsafe) private var _previouslyEnrolledUserId: String? // protected by lock
    nonisolated(unsafe) private var offerShownSet: Set<String> = [] // protected by lock
    private let lock = NSLock()

    nonisolated var previouslyEnrolledUserId: String? {
        lock.withLock { _previouslyEnrolledUserId }
    }

    nonisolated func setPreviouslyEnrolledUserId(_ userId: String?) {
        lock.withLock { _previouslyEnrolledUserId = userId }
    }

    nonisolated func hasSeenOffer(for userId: String) -> Bool {
        lock.withLock { offerShownSet.contains(userId) }
    }

    nonisolated func markOfferShown(for userId: String) {
        lock.withLock { offerShownSet.insert(userId) }
    }
}
