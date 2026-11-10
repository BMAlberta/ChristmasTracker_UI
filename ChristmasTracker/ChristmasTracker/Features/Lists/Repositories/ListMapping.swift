//
//  ListMapping.swift
//  ChristmasTracker
//
//  Pure mapping from the generated list schemas to the domain models. This is the repository
//  boundary: nothing past it sees a generated type. Every switch over a generated enum is
//  exhaustive with no default case, so a new server value fails to compile instead of being
//  silently mapped.
//

import Foundation
import TrackerAPI

nonisolated func mapListPerson(_ person: Components.Schemas.PersonRef) -> ListPerson {
    ListPerson(id: person.id, displayName: person.displayName)
}

nonisolated func mapListSummary(_ summary: Components.Schemas.ListSummary) -> GiftList {
    let core = summary.value1
    let original = summary.value2
    return GiftList(
        id: core.id,
        name: core.name,
        theme: core.theme,
        year: core.year,
        visibility: mapListVisibility(core.visibility),
        status: mapListStatus(core.status),
        recipient: mapListPerson(core.recipient),
        owner: mapListPerson(core.owner),
        coOwner: core.coOwner.map(mapListPerson),
        myRole: ListRole(wire: summary),
        capabilities: ListCapabilities(
            isRecipient: original.isRecipient,
            canSeeGiftActivity: original.canSeeGiftActivity,
            canPurchase: original.canPurchase,
            canAddOffList: original.canAddOffList,
            canSeeOffList: original.canSeeOffList,
            canCreateItem: original.canCreateItem,
            canSeeMembers: core.canSeeMembers,
            canEditList: core.canEditList,
            canDeleteList: core.canDeleteList,
            canManageMembers: core.canManageMembers,
            canSetCoOwner: core.canSetCoOwner,
            canLeaveList: core.canLeaveList
        ),
        memberCount: core.memberCount,
        // Count hardening: a viewer who cannot see gift activity never gets counts, even if the
        // server sent them.
        itemCount: original.canSeeGiftActivity ? core.itemCount : nil,
        purchasedCount: original.canSeeGiftActivity ? core.purchasedCount : nil,
        createdAt: core.createdAt,
        updatedAt: core.updatedAt
    )
}

nonisolated func mapListDetail(_ detail: Components.Schemas.ListDetail) -> ListDetail {
    mapListSummary(detail.value1).asDetail(members: detail.value2.members.map { $0.map(mapMemberSummary) })
}

nonisolated func mapMemberSummary(_ member: Components.Schemas.MemberSummary) -> ListMember {
    ListMember(
        id: member.id,
        userId: member.userId,
        displayName: member.displayName,
        email: member.email,
        role: mapListMemberRole(member.role),
        status: mapListMemberStatus(member.status),
        invitedAt: member.invitedAt,
        acceptedAt: member.acceptedAt,
        expiresAt: member.expiresAt
    )
}

nonisolated private func mapListVisibility(_ value: Components.Schemas.ListVisibility) -> ListVisibility {
    switch value {
    case ._private: return .private
    case .inviteOnly: return .inviteOnly
    case .friendsOnly: return .friendsOnly
    case ._public: return .public
    }
}

nonisolated private func mapListStatus(_ value: Components.Schemas.ListStatus) -> ListStatus {
    switch value {
    case .draft: return .draft
    case .active: return .active
    case .archived: return .archived
    }
}

nonisolated private func mapListMemberRole(_ value: Components.Schemas.MembershipRole) -> ListMemberRole {
    switch value {
    case .member: return .member
    case .viewer: return .viewer
    }
}

nonisolated private func mapListMemberStatus(
    _ value: Components.Schemas.MemberSummary.StatusPayload
) -> ListMemberStatus {
    switch value {
    case .invited: return .invited
    case .active: return .active
    case .removed: return .removed
    case .expired: return .expired
    }
}
