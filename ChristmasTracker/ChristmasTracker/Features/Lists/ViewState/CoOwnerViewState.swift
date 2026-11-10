//
//  CoOwnerViewState.swift
//  ChristmasTracker
//
//  Pure view state and form rules of the co-owner control in the edit screen. "Change co-owner"
//  follows the canSetCoOwner flag. The current co-owner is shown by display name only.
//

import Foundation

nonisolated struct CoOwnerSectionState: Equatable, Sendable {

    /// Whether the co-owner can be cleared through the generated client. It cannot: the generated
    /// update payload declares `coOwnerEmail` as a plain `String?` with compiler-synthesized
    /// Codable, which omits a nil, so an explicit JSON null can never be sent. "Remove co-owner"
    /// stays hidden until the contract offers an explicit clearing mechanism.
    static let clearingSupported = false

    let currentCoOwnerName: String?
    let showsChange: Bool
    let showsRemove: Bool

    init(detail: ListDetail) {
        let permissions = ListPermissions(detail.capabilities)
        currentCoOwnerName = detail.coOwner?.displayName
        showsChange = permissions.canSetCoOwner
        showsRemove = permissions.canSetCoOwner && detail.coOwner != nil && Self.clearingSupported
    }
}

/// The co-owner email rule (the project's existing email semantics, after trimming) and the
/// request builder.
nonisolated enum CoOwnerFormValidation {

    static func isValidEmail(_ email: String) -> Bool {
        RegistrationFormValidator.isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A valid address and no mutation in flight.
    static func canSubmit(email: String, isMutating: Bool) -> Bool {
        !isMutating && isValidEmail(email)
    }

    /// `.set(email:)` with the trimmed address, or nil when the address is invalid.
    static func makeChange(email: String) -> CoOwnerChange? {
        guard isValidEmail(email) else { return nil }
        return .set(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
