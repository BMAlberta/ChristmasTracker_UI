//
//  MembersSectionView.swift
//  ChristmasTracker
//
//  The Members section of the list detail. It renders a MembersSectionState and reports taps;
//  the detail screen owns the confirmations and the service calls. Design tokens only.
//

import SwiftUI

struct MembersSectionView: View {
    let state: MembersSectionState
    let isMutating: Bool
    let onAdd: () -> Void
    let onRemove: (MemberRowState) -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            if state.showsRoster {
                rosterCard
            }
            if state.showsLeave {
                leaveButton
            }
        }
    }

    // MARK: - Roster

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Members")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimaryColor)
                Spacer()
                Text(state.memberCountText)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
            ForEach(state.rows) { row in
                MemberRosterRow(row: row, isMutating: isMutating, onRemove: { onRemove(row) })
            }
            if state.showsAdd {
                addButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Label("Add member", systemImage: "person.badge.plus")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.primaryColor)
        .disabled(isMutating)
        .accessibilityHint("Invites a person to this list by email")
        .accessibilityIdentifier("listDetail.addMemberButton")
    }

    private var leaveButton: some View {
        Button(role: .destructive, action: onLeave) {
            Label("Leave list", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .disabled(isMutating)
        .accessibilityHint("Removes this list from your lists after you confirm")
        .accessibilityIdentifier("listDetail.leaveButton")
    }
}

// MARK: - Row

private struct MemberRosterRow: View {
    let row: MemberRowState
    let isMutating: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(row.displayName)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)
                Text(row.roleLabel)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)

            if row.canRemove {
                Button(action: onRemove) {
                    Label("Remove", systemImage: "person.badge.minus")
                        .labelStyle(.iconOnly)
                        .font(.appBody)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isMutating)
                .accessibilityLabel("Remove \(row.displayName)")
                .accessibilityHint("Asks you to confirm before removing this person")
                .accessibilityIdentifier("listDetail.removeMemberButton")
            }
        }
        .frame(minHeight: 44)
    }
}
