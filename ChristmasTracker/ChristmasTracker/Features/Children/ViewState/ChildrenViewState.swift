//
//  ChildrenViewState.swift
//  ChristmasTracker
//
//  Pure view states and form rules for the Children screen and the recipient picker of the
//  create-list form. Children's names are personal data: nothing here logs them.
//

import Foundation

// MARK: - Load phase

nonisolated enum ChildrenLoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(ChildError)
}

// MARK: - Children screen

nonisolated struct ChildRowState: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let relationshipTitle: String
    /// True while this child's deletion (planning, archiving, deleting) is running.
    var isDeleting: Bool = false

    var accessibilityLabel: String {
        isDeleting ? "\(title), \(relationshipTitle), being removed" : "\(title), \(relationshipTitle)"
    }
}

/// The banner for a finished deletion that did not remove the child.
nonisolated struct ChildDeletionBanner: Equatable, Sendable {
    let state: InlineErrorBannerState
}

nonisolated struct ChildDeleteConfirmation: Equatable, Sendable {
    let title: String
    let message: String
    let confirmButtonTitle: String
}

nonisolated struct ChildrenState: Equatable, Sendable {
    let rows: [ChildRowState]
    let showsLoading: Bool
    let showsEmptyState: Bool
    let errorMessage: String?

    var emptyText: String {
        "No children added yet."
    }

    init(children: [Child], phase: ChildrenLoadPhase, deletingChildId: String? = nil) {
        rows = children.map {
            ChildRowState(
                id: $0.id,
                title: $0.shownName,
                relationshipTitle: $0.relationship.title,
                isDeleting: $0.id == deletingChildId
            )
        }
        switch phase {
        case .idle:
            showsLoading = false
            showsEmptyState = false
            errorMessage = nil
        case .loading:
            showsLoading = true
            showsEmptyState = false
            errorMessage = nil
        case .loaded:
            showsLoading = false
            showsEmptyState = children.isEmpty
            errorMessage = nil
        case .failed(let error):
            showsLoading = false
            showsEmptyState = false
            errorMessage = ChildErrorPresentation(error).message
        }
    }

    static let blockedMessage =
        "An active list of this child can't be archived by you. The person who owns it must archive it first."

    /// The confirmation for a plan; nil for a blocked plan (the banner explains instead).
    static func deleteConfirmation(for child: Child, plan: ChildDeletionPlan) -> ChildDeleteConfirmation? {
        switch plan {
        case .blocked:
            return nil
        case .deleteNow:
            return ChildDeleteConfirmation(
                title: "Delete this child?",
                message: "\(child.shownName) will be removed.",
                confirmButtonTitle: "Delete"
            )
        case .archiveThenDelete(let listIds):
            let count = listIds.count
            return ChildDeleteConfirmation(
                title: count == 1
                    ? "Archive 1 list and delete this child?"
                    : "Archive \(count) lists and delete this child?",
                message: "\(child.shownName)'s active lists will move to Archived and can't be edited afterwards. Archived lists stay available there. This can't be undone.",
                confirmButtonTitle: "Archive and Delete"
            )
        }
    }

    /// The banner for a result that did not remove the child; nil for success.
    static func banner(for result: ChildDeletionResult) -> ChildDeletionBanner? {
        switch result {
        case .deleted, .archivedThenDeleted:
            return nil
        case .partialFailure(let archived, let total, let error):
            return ChildDeletionBanner(state: InlineErrorBannerState(
                message: "Archived \(archived) of \(total) lists. The child was not removed.",
                canRetry: ChildErrorPresentation(error).isRetryable,
                isDismissible: true
            ))
        case .failed(let error):
            return ChildDeletionBanner(state: InlineErrorBannerState(
                message: error.userMessage,
                canRetry: ChildErrorPresentation(error).isRetryable,
                isDismissible: true
            ))
        case .blocked:
            return ChildDeletionBanner(state: InlineErrorBannerState(
                message: blockedMessage,
                canRetry: false,
                isDismissible: true
            ))
        }
    }

    static func progressAnnouncement(for plan: ChildDeletionPlan) -> String {
        switch plan {
        case .archiveThenDelete: "Archiving lists"
        case .deleteNow, .blocked: "Deleting child"
        }
    }

    /// nil for results whose banner announces itself.
    static func resultAnnouncement(for result: ChildDeletionResult) -> String? {
        switch result {
        case .deleted:
            return "Child removed"
        case .archivedThenDeleted(let count):
            return count == 1
                ? "Archived 1 list and removed the child"
                : "Archived \(count) lists and removed the child"
        case .partialFailure, .failed, .blocked:
            return nil
        }
    }

    /// False while a deletion runs or the child service is mutating.
    static func deleteControlsEnabled(isMutating: Bool, deletingChildId: String?) -> Bool {
        !isMutating && deletingChildId == nil
    }
}

// MARK: - Add child form

nonisolated struct ChildFormValidity: Equatable, Sendable {
    let firstNameInvalid: Bool
    let lastNameInvalid: Bool
    let displayNameInvalid: Bool

    var isValid: Bool {
        !firstNameInvalid && !lastNameInvalid && !displayNameInvalid
    }
}

nonisolated enum ChildFormValidation {
    static let nameLimit = 100
    static let displayNameLimit = 200

    static func validate(firstName: String, lastName: String, displayName: String) -> ChildFormValidity {
        let display = trimmed(displayName)
        return ChildFormValidity(
            firstNameInvalid: !(1...nameLimit).contains(trimmed(firstName).count),
            lastNameInvalid: !(1...nameLimit).contains(trimmed(lastName).count),
            displayNameInvalid: !display.isEmpty && display.count > displayNameLimit
        )
    }

    /// Valid input and no mutation in flight: a form cannot be submitted twice.
    static func canSubmit(firstName: String, lastName: String, displayName: String, isMutating: Bool) -> Bool {
        !isMutating && validate(firstName: firstName, lastName: lastName, displayName: displayName).isValid
    }

    static func makeInput(
        firstName: String,
        lastName: String,
        displayName: String,
        relationship: ChildRelationship
    ) -> CreateChildInput {
        let display = trimmed(displayName)
        return CreateChildInput(
            firstName: trimmed(firstName),
            lastName: trimmed(lastName),
            displayName: display.isEmpty ? nil : display,
            relationship: relationship
        )
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Recipient picker

nonisolated struct RecipientOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let isSelf: Bool
}

/// The recipient picker of the create-list form. "For me" is always offered, so a slow or failed
/// child fetch never blocks creating a list for yourself. Children are offered only once loaded.
nonisolated struct CreateListRecipientOptions: Equatable, Sendable {
    let options: [RecipientOption]
    let showsLoading: Bool
    let showsEmptyHint: Bool
    let errorMessage: String?

    private let currentUserId: String

    var defaultSelectionId: String {
        currentUserId
    }

    init(currentUserId: String, children: [Child], phase: ChildrenLoadPhase) {
        self.currentUserId = currentUserId
        var offered = [RecipientOption(id: currentUserId, title: "For me", isSelf: true)]
        switch phase {
        case .idle:
            showsLoading = false
            showsEmptyHint = false
            errorMessage = nil
        case .loading:
            showsLoading = true
            showsEmptyHint = false
            errorMessage = nil
        case .loaded:
            offered += children.map { RecipientOption(id: $0.id, title: $0.shownName, isSelf: false) }
            showsLoading = false
            showsEmptyHint = children.isEmpty
            errorMessage = nil
        case .failed(let error):
            showsLoading = false
            showsEmptyHint = false
            errorMessage = ChildErrorPresentation(error).message
        }
        options = offered
    }

    /// The visible selection kept valid: `current` when it is an offered option, otherwise the
    /// default (so a child that is no longer offered resets the picker to "For me").
    func resolvedSelection(current: String?) -> String {
        guard let current, options.contains(where: { $0.id == current }) else { return defaultSelectionId }
        return current
    }

    /// The recipient id for a picker selection: an offered option's id, otherwise the current
    /// user. Never an arbitrary id.
    func recipientId(forSelection selection: String?) -> String {
        guard let selection, options.contains(where: { $0.id == selection }) else { return currentUserId }
        return selection
    }
}
