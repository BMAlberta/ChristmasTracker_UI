//
//  CoOwnerViewState.swift
//  ChristmasTracker
//
//  Pure view state and form rules of the co-owner control in the edit screen. "Change co-owner"
//  follows the canSetCoOwner flag. The current co-owner is shown by display name only.
//

import Foundation

nonisolated struct CoOwnerSectionState: Equatable, Sendable {

    let currentCoOwnerName: String?
    let showsChange: Bool
    let showsRemove: Bool

    init(detail: ListDetail) {
        let permissions = ListPermissions(detail.capabilities)
        currentCoOwnerName = detail.coOwner?.displayName
        showsChange = permissions.canSetCoOwner
        showsRemove = permissions.canSetCoOwner && detail.coOwner != nil
    }
}

/// The texts of the "Remove co-owner" confirmation dialog.
nonisolated enum CoOwnerRemoveConfirmation {
    static let confirmButtonTitle = "Remove"

    static func title(displayName: String) -> String {
        "Remove \(displayName) as co-owner?"
    }

    static func message(displayName: String) -> String {
        "\(displayName) will no longer be a co-owner of this list."
    }
}

nonisolated enum CoOwnerRemoval {

    /// What the screen shows after removeCoOwner threw: nil for a cancellation, otherwise the
    /// ListError (any other error is shown as the server error).
    static func presentation(for error: any Error) -> ListErrorPresentation? {
        if error is CancellationError { return nil }
        return ListErrorPresentation((error as? ListError) ?? .server)
    }

    /// The Remove button is enabled only when no mutation or save is in flight.
    static func canRemove(isMutating: Bool, isSaving: Bool) -> Bool {
        !isMutating && !isSaving
    }
}

/// The Edit List action whose failure the error banner is showing.
nonisolated enum EditFailedAction: Equatable, Sendable {
    case save
    case removeCoOwner
}

/// Try Again re-runs the action that failed, never a different one.
nonisolated enum EditRetry {
    static func action(after failed: EditFailedAction?) -> EditFailedAction? {
        failed
    }
}

nonisolated enum EditListDetailSource {

    /// The live detail when it is the same list as the snapshot, otherwise the snapshot.
    static func resolve(snapshot: ListDetail, live: ListDetail?) -> ListDetail {
        if let live, live.id == snapshot.id { return live }
        return snapshot
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
