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
    /// The screen owns this value; the dialogs are shown from it and report through the closures.
    let dialog: ConfirmationPresentation<MembersDialogTarget>
    let onAdd: () -> Void
    let onRequest: (MembersDialogTarget) -> Void
    let onCancel: () -> Void
    let onConfirm: (MembersDialogTarget) -> Void

    /// Competing member controls are off while a mutation runs or a dialog is open.
    private var controlsDisabled: Bool {
        isMutating || !dialog.isIdle
    }

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
                MemberRosterRow(
                    row: row,
                    controlsDisabled: controlsDisabled,
                    isConfirming: dialog.isConfirming(.removeMember(userId: row.userId)),
                    onRequest: { onRequest(.removeMember(userId: row.userId)) },
                    onCancel: onCancel,
                    onConfirm: { onConfirm(.removeMember(userId: row.userId)) }
                )
            }
            if state.showsAdd {
                addButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Label("Add member", systemImage: "person.badge.plus")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(controlsDisabled)
        .accessibilityHint("Invites a person to this list by email")
        .accessibilityIdentifier("listDetail.addMemberButton")
    }

    private var leaveButton: some View {
        Button(role: .destructive) {
            onRequest(.leave)
        } label: {
            Label("Leave list", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .destructiveTint()
        .disabled(controlsDisabled)
        .accessibilityHint("Removes this list from your lists after you confirm")
        .accessibilityIdentifier("listDetail.leaveButton")
        // Attached to this trigger, not to the screen.
        .confirmationDialog(
            MembersSectionState.leaveConfirmation.title,
            isPresented: Binding(
                get: { dialog.isConfirming(.leave) },
                set: { if !$0 { onCancel() } }
            ),
            titleVisibility: .visible
        ) {
            Button(MembersSectionState.leaveConfirmation.confirmButtonTitle, role: .destructive) {
                onConfirm(.leave)
            }
            .destructiveTint()
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(MembersSectionState.leaveConfirmation.message)
        }
    }
}

// MARK: - Row

private struct MemberRosterRow: View {
    let row: MemberRowState
    let controlsDisabled: Bool
    let isConfirming: Bool
    let onRequest: () -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

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
                let confirmation = MembersSectionState.removeConfirmation(for: row)
                Button(role: .destructive, action: onRequest) {
                    Label("Remove", systemImage: "person.badge.minus")
                        .labelStyle(.iconOnly)
                        .font(.appBody)
                        .foregroundStyle(Color.destructiveColor)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(controlsDisabled)
                .accessibilityLabel("Remove \(row.displayName)")
                .accessibilityHint("Asks you to confirm before removing this person")
                .accessibilityIdentifier("listDetail.removeMemberButton")
                // Attached to this row's own Remove button, not to the screen.
                .confirmationDialog(
                    confirmation.title,
                    isPresented: Binding(
                        get: { isConfirming },
                        set: { if !$0 { onCancel() } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button(confirmation.confirmButtonTitle, role: .destructive, action: onConfirm)
                        .destructiveTint()
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(confirmation.message)
                }
            }
        }
        .frame(minHeight: 44)
    }
}
