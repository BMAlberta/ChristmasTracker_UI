//
//  ListViewState.swift
//  ChristmasTracker
//
//  Pure view states for the list screens. They are built from domain models and answer every
//  "should this show" question through ListPermissions (server flags), never through the
//  viewer's role. When counts are hidden the fields are simply nil or false: nothing here
//  (no note, zero or label) hints that hidden items exist.
//

import Foundation

// MARK: - Row

/// What one list row or card shows on the dashboard.
nonisolated struct ListRowState: Equatable, Sendable {
    let title: String
    let subtitle: String
    let year: Int
    let badgeTitle: String
    let badgeTone: ListRoleBadge.Tone
    let showsCounts: Bool
    let itemCountText: String?
    let purchasedCountText: String?
    let showsProgress: Bool
    let progress: Double?
    let showsDeleteAction: Bool
    let category: ListCategory
    let isArchived: Bool
    let showsArchivedBadge: Bool

    init(list: GiftList) {
        let permissions = ListPermissions(list.capabilities)
        let badge = ListRoleBadge(list: list)
        let countsVisible = permissions.showsCounts(itemCount: list.itemCount, purchasedCount: list.purchasedCount)
        let progressVisible = permissions.showsProgress(itemCount: list.itemCount, purchasedCount: list.purchasedCount)

        title = list.name
        subtitle = "For \(list.recipientName)"
        year = list.year
        badgeTitle = badge.title
        badgeTone = badge.tone
        showsCounts = countsVisible
        itemCountText = countsVisible ? list.itemCount.map(ListCountText.items) : nil
        purchasedCountText = countsVisible ? list.purchasedCount.map(ListCountText.purchased) : nil
        showsProgress = progressVisible
        progress = progressVisible ? list.progress : nil
        showsDeleteAction = permissions.canDeleteList
        category = permissions.category
        isArchived = list.status == .archived
        showsArchivedBadge = list.status == .archived
    }

    var accessibilityLabel: String {
        var parts = [title, subtitle, String(year), badgeTitle]
        if showsArchivedBadge {
            parts.append(ListArchivedBadge.title)
        }
        if let itemCountText, let purchasedCountText {
            parts.append(itemCountText)
            parts.append(purchasedCountText)
        }
        return parts.joined(separator: ", ")
    }

    var accessibilityHint: String {
        "Opens the list"
    }
}

// MARK: - Detail

/// What the list detail screen shows and offers.
nonisolated struct ListDetailState: Equatable, Sendable {
    let title: String
    let subtitle: String
    let year: Int
    let theme: String?
    let visibilityTitle: String
    let visibilityIcon: String
    let badgeTitle: String
    let badgeTone: ListRoleBadge.Tone
    let showsEditAction: Bool
    let showsDeleteAction: Bool
    let memberCountText: String
    let showsMembersSection: Bool
    let showsStatsCard: Bool
    let itemCountText: String?
    let purchasedCountText: String?
    let showsProgress: Bool
    let progress: Double?
    let showsAddItemAction: Bool
    let isArchived: Bool
    let showsArchivedBadge: Bool

    init(detail: ListDetail) {
        let permissions = ListPermissions(detail.capabilities)
        let badge = ListRoleBadge(detail: detail)
        let countsVisible = permissions.showsCounts(itemCount: detail.itemCount, purchasedCount: detail.purchasedCount)
        let progressVisible = permissions.showsProgress(
            itemCount: detail.itemCount,
            purchasedCount: detail.purchasedCount
        )

        title = detail.name
        subtitle = "For \(detail.recipientName)"
        year = detail.year
        theme = detail.theme
        visibilityTitle = detail.visibility.title
        visibilityIcon = detail.visibility.icon
        badgeTitle = badge.title
        badgeTone = badge.tone
        showsEditAction = permissions.canEditList
        showsDeleteAction = permissions.canDeleteList
        memberCountText = ListCountText.members(detail.memberCount)
        showsMembersSection = permissions.showsMembersSection && detail.members != nil
        showsStatsCard = countsVisible
        itemCountText = countsVisible ? detail.itemCount.map(ListCountText.items) : nil
        purchasedCountText = countsVisible ? detail.purchasedCount.map(ListCountText.purchased) : nil
        showsProgress = progressVisible
        progress = progressVisible ? detail.progress : nil
        showsAddItemAction = detail.capabilities.canCreateItem
        isArchived = detail.status == .archived
        showsArchivedBadge = detail.status == .archived
    }
}

// MARK: - Count texts

private nonisolated enum ListCountText {
    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    static func purchased(_ count: Int) -> String {
        "\(count) purchased"
    }

    static func members(_ count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}

// MARK: - Visibility

nonisolated extension ListVisibility {
    /// The user-facing name.
    var title: String {
        switch self {
        case .private: return "Private"
        case .inviteOnly: return "Invite Only"
        case .friendsOnly: return "Friends Only"
        case .public: return "Public"
        }
    }

    /// SF Symbol name for the visibility.
    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .inviteOnly: return "person.2.fill"
        case .friendsOnly: return "person.crop.circle.badge.checkmark"
        case .public: return "globe"
        }
    }
}

// MARK: - Forms

nonisolated struct CreateFormValidity: Equatable, Sendable {
    let nameEmptyOrTooLong: Bool
    let themeTooLong: Bool
    let yearOutOfRange: Bool

    var isValid: Bool {
        !nameEmptyOrTooLong && !themeTooLong && !yearOutOfRange
    }
}

nonisolated struct EditFormValidity: Equatable, Sendable {
    let nameEmptyOrTooLong: Bool
    let themeTooLong: Bool

    var isValid: Bool {
        !nameEmptyOrTooLong && !themeTooLong
    }
}

/// Rules and request builders of the create and edit forms.
nonisolated enum ListFormValidation {
    static let nameLimit = 200
    static let themeLimit = 500
    static let yearRange = 2000...2100

    static let selectableVisibilities: [ListVisibility] = [.private, .inviteOnly, .friendsOnly, .public]

    static func validateCreate(name: String, theme: String, year: Int) -> CreateFormValidity {
        CreateFormValidity(
            nameEmptyOrTooLong: isNameInvalid(name),
            themeTooLong: isThemeTooLong(theme),
            yearOutOfRange: !yearRange.contains(year)
        )
    }

    static func validateEdit(name: String, theme: String) -> EditFormValidity {
        EditFormValidity(nameEmptyOrTooLong: isNameInvalid(name), themeTooLong: isThemeTooLong(theme))
    }

    static func makeCreateInput(
        recipientId: String,
        name: String,
        theme: String,
        year: Int,
        visibility: ListVisibility
    ) -> CreateListInput {
        let trimmedTheme = trimmed(theme)
        return CreateListInput(
            recipientId: recipientId,
            year: year,
            name: trimmed(name),
            theme: trimmedTheme.isEmpty ? nil : trimmedTheme,
            visibility: visibility
        )
    }

    /// Only the changed fields, or nil when nothing changed. UpdateListInput.theme nil means
    /// "leave unchanged", so clearing an existing theme sends the empty string.
    static func makeUpdateInput(
        original: ListDetail,
        name: String,
        theme: String,
        visibility: ListVisibility,
        coOwner: CoOwnerChange = .unchanged
    ) -> UpdateListInput? {
        let newName = trimmed(name)
        let newTheme = trimmed(theme)
        let oldTheme = trimmed(original.theme ?? "")

        let nameChange: String? = newName != original.name ? newName : nil
        let themeChange: String? = newTheme != oldTheme ? newTheme : nil
        let visibilityChange: ListVisibility? = visibility != original.visibility ? visibility : nil

        guard nameChange != nil || themeChange != nil || visibilityChange != nil || coOwner != .unchanged else {
            return nil
        }
        return UpdateListInput(name: nameChange, theme: themeChange, visibility: visibilityChange, coOwner: coOwner)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isNameInvalid(_ name: String) -> Bool {
        let count = trimmed(name).count
        return count < 1 || count > nameLimit
    }

    private static func isThemeTooLong(_ theme: String) -> Bool {
        trimmed(theme).count > themeLimit
    }
}

// MARK: - Errors

/// How a ListError is shown: the message, whether a retry makes sense, and whether the screen
/// should be left because the list is gone or read-only.
nonisolated struct ListErrorPresentation: Equatable, Sendable {
    let message: String
    let isRetryable: Bool
    let shouldLeaveScreen: Bool

    init(_ error: ListError) {
        message = error.userMessage
        switch error {
        case .network, .server, .rateLimited, .invalidResponse:
            isRetryable = true
        case .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
             .validation, .unauthorized, .sessionEnded, .memberEmailNotFound, .alreadyMember,
             .membershipNotFound:
            isRetryable = false
        }
        switch error {
        case .notFound:
            shouldLeaveScreen = true
        case .forbidden, .archivedReadOnly, .recipientNotFound, .duplicateRecipientYear, .validation, .rateLimited,
             .unauthorized, .sessionEnded, .network, .invalidResponse, .server, .memberEmailNotFound,
             .alreadyMember, .membershipNotFound:
            shouldLeaveScreen = false
        }
    }
}

/// When the detail and edit screens leave because their list is gone or read-only. True exactly
/// for the errors ListErrorPresentation marks with shouldLeaveScreen.
nonisolated enum ListScreenExit {
    static func shouldDismissDetail(for error: ListError?) -> Bool {
        shouldLeave(error)
    }

    static func shouldDismissEdit(for error: ListError?) -> Bool {
        shouldLeave(error)
    }

    /// The detail screen of `openListId` leaves when that very list was reported gone.
    static func shouldDismissDetail(goneListId: String?, openListId: String) -> Bool {
        goneListId == openListId
    }

    /// The edit sheet of `editedListId` leaves when that very list was reported gone.
    static func shouldDismissEdit(goneListId: String?, editedListId: String) -> Bool {
        goneListId == editedListId
    }

    private static func shouldLeave(_ error: ListError?) -> Bool {
        guard let error else { return false }
        return ListErrorPresentation(error).shouldLeaveScreen
    }
}

/// What the detail screen does once an archive returned normally. The archive itself succeeded,
/// but the reload that follows may have failed and left its error on the service: that error is
/// shown (no retry that would archive again) and the screen stays.
nonisolated enum ListArchiveCompletion: Equatable, Sendable {
    case dismiss
    case showError(ListErrorPresentation)

    static func after(serviceError: ListError?) -> ListArchiveCompletion {
        guard let serviceError else { return .dismiss }
        return .showError(ListErrorPresentation(serviceError))
    }
}

/// Remembers which error the user dismissed. A new operation resets it, so the same failure
/// after a new attempt is shown again.
nonisolated struct ListErrorDismissal: Equatable, Sendable {
    private(set) var dismissed: ListError?

    init() {}

    mutating func dismiss(_ error: ListError?) {
        guard let error else { return }
        dismissed = error
    }

    mutating func reset() {
        dismissed = nil
    }

    func visible(_ current: ListError?) -> ListError? {
        guard let current, current != dismissed else { return nil }
        return current
    }
}

// MARK: - Items scope

/// Items render only under the list they were loaded for.
nonisolated enum ListItemsScope {
    static func itemsToShow<Item>(_ items: [Item], currentListId: String?, listId: String) -> [Item] {
        currentListId == listId ? items : []
    }
}

// MARK: - Delete confirmation

/// Deleting a list is presented as archiving it.
nonisolated enum ListArchiveConfirmation {
    static let title = "Archive this list?"
    static let message = "The list moves to Archived and can no longer be edited. "
        + "Items and purchases can still be recorded there."
    static let confirmButtonTitle = "Archive List"
    static let actionTitle = "Archive List"
}

nonisolated enum ListArchivedBadge {
    static let title = "Archived"
}

// MARK: - Segments

/// The two tabs of the lists screen.
nonisolated enum ListSegment: String, CaseIterable, Sendable {
    case active
    case archived

    var title: String {
        switch self {
        case .active: return "Active"
        case .archived: return "Archived"
        }
    }

    /// Active holds ACTIVE and DRAFT lists; Archived holds ARCHIVED ones.
    func includes(_ status: ListStatus) -> Bool {
        switch (self, status) {
        case (.active, .active), (.active, .draft), (.archived, .archived):
            return true
        case (.active, .archived), (.archived, .active), (.archived, .draft):
            return false
        }
    }
}

/// What one segment shows: its lists and the copy of its empty state. The screen applies the
/// search before building this, so no matching happens here.
nonisolated struct ListSegmentState: Equatable, Sendable {
    let lists: [GiftList]
    let emptyTitle: String
    let emptyMessage: String
    let showsCreateAction: Bool

    init(segment: ListSegment, lists: [GiftList], isSearching: Bool) {
        self.lists = lists.filter { segment.includes($0.status) }
        if isSearching {
            emptyTitle = "No Results"
            emptyMessage = "No lists match your search."
            showsCreateAction = false
            return
        }
        switch segment {
        case .active:
            emptyTitle = "No active lists"
            emptyMessage = "Create your first gift list to get started"
            showsCreateAction = true
        case .archived:
            emptyTitle = "No archived lists"
            emptyMessage = "Archived lists appear here."
            showsCreateAction = false
        }
    }
}
