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

    var accessibilityLabel: String {
        "\(title), \(relationshipTitle)"
    }
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

    init(children: [Child], phase: ChildrenLoadPhase) {
        rows = children.map {
            ChildRowState(id: $0.id, title: $0.shownName, relationshipTitle: $0.relationship.title)
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

    static func deleteConfirmation(for child: Child) -> ChildDeleteConfirmation {
        ChildDeleteConfirmation(
            title: "Delete this child?",
            message: "\(child.shownName) will be removed. This can't be undone.",
            confirmButtonTitle: "Delete"
        )
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
