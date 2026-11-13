//
//  ChildrenView.swift
//  ChristmasTracker
//
//  The Children screen, reached from the profile. It renders ChildrenState and calls the
//  ChildService. Children's names are personal data: nothing here logs them or puts them in an
//  accessibility identifier.
//

import SwiftUI

struct ChildrenView: View {
    @Environment(\.childService) private var childService
    @Environment(\.listService) private var listService

    @State private var showsAddChild = false
    // The screen outlives its rows, so the deletion presentation lives here, not in a row.
    @State private var deletion = ChildDeletionPresentation.idle
    @State private var deletionFailure: DeletionFailure?
    @State private var deletionTask: Task<Void, Never>?

    /// A deletion that did not remove the child, held only in this screen's state.
    private struct DeletionFailure: Equatable {
        let childId: String
        let banner: ChildDeletionBanner
    }

    private var state: ChildrenState {
        ChildrenState(children: childService.children, phase: childService.phase, deletion: deletion)
    }

    var body: some View {
        let state = state
        let controlsEnabled = ChildrenState.deleteControlsEnabled(
            isMutating: childService.isMutating,
            deletion: deletion
        )
        return List {
            if let failure = deletionFailure {
                deletionBanner(failure)
            }
            if state.showsLoading, state.rows.isEmpty {
                loadingRow
            }
            if let message = state.errorMessage {
                errorRow(message: message)
            }
            if state.showsEmptyState {
                emptyRow(text: state.emptyText)
            }
            ForEach(state.rows) { row in
                if let child = childService.children.first(where: { $0.id == row.id }) {
                    ChildRow(
                        row: row,
                        isConfirmationPresented: confirmationBinding(for: row.id),
                        confirmation: deletion.confirmingPlan(for: row.id).flatMap {
                            ChildrenState.deleteConfirmation(for: child, plan: $0)
                        },
                        confirmingPlan: deletion.confirmingPlan(for: row.id),
                        controlsEnabled: controlsEnabled,
                        onRequestDelete: { requestDelete(childId: row.id) },
                        onConfirm: { confirm(childId: row.id, plan: $0) }
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("Children")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsAddChild = true
                } label: {
                    Label("Add child", systemImage: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(childService.isMutating)
                .accessibilityHint("Adds a child to your profile")
                .accessibilityIdentifier("children.addButton")
            }
        }
        .sheet(isPresented: $showsAddChild) {
            AddChildView()
        }
        .refreshable {
            await childService.loadChildren()
        }
        .task {
            await childService.loadChildren()
        }
        .onChange(of: childService.children.map(\.id)) { _, ids in
            deletion = deletion.childrenChanged(existingIds: ids)
        }
        .onChange(of: childService.sessionGeneration) {
            cancelAndReset()
        }
        .onDisappear {
            cancelAndReset()
        }
    }

    // MARK: - Deletion banner

    private func deletionBanner(_ failure: DeletionFailure) -> some View {
        InlineErrorBanner(
            state: failure.banner.state,
            onTryAgain: { retryDeletion(failure) },
            onDismiss: { deletionFailure = nil }
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - States

    private var loadingRow: some View {
        HStack(spacing: AppSpacing.md) {
            ProgressView()
            Text("Loading children...")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .listRowBackground(Color.surfaceColor)
        .accessibilityElement(children: .combine)
    }

    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label {
                Text(message)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            Button {
                Task { await childService.loadChildren() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.appHeadline)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.primaryColor)
            .accessibilityHint("Loads your children again")
        }
        .listRowBackground(Color.surfaceColor)
    }

    private func emptyRow(text: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.2")
                .font(.appTitle1)
                .foregroundStyle(Color.textMutedColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .listRowBackground(Color.surfaceColor)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    /// Runs deletion work in the screen's task, which is cancelled when the screen disappears.
    private func startDeletionWork(_ work: @escaping @MainActor () async -> Void) {
        deletionTask?.cancel()
        deletionTask = Task { await work() }
    }

    private func showBanner(_ banner: ChildDeletionBanner?, for childId: String) {
        deletionFailure = banner.map { DeletionFailure(childId: childId, banner: $0) }
    }

    /// Applies a finished deletion: announces success, or holds the banner. nil shows nothing.
    private func finish(_ result: ChildDeletionResult?, for childId: String) {
        guard let result else { return }
        if let text = ChildrenState.resultAnnouncement(for: result) {
            AccessibilityNotification.Announcement(text).post()
        }
        showBanner(ChildrenState.banner(for: result), for: childId)
    }

    private func makeFlow() -> ChildDeletionFlow {
        ChildDeletionFlow(childService: childService, listService: listService)
    }

    private func announce(_ text: String?) {
        guard let text else { return }
        AccessibilityNotification.Announcement(text).post()
    }

    private func cancelAndReset() {
        deletionTask?.cancel()
        deletionTask = nil
        deletion = deletion.reset()
    }

    /// The dialog's presented flag, read from the screen's presentation. Dismissing it cancels
    /// the confirmation only while that child is still the one being confirmed.
    private func confirmationBinding(for childId: String) -> Binding<Bool> {
        Binding(
            get: { deletion.isConfirming(childId: childId) },
            set: { presented in
                if !presented, deletion.isConfirming(childId: childId) {
                    deletion = deletion.cancelConfirmation()
                }
            }
        )
    }

    /// Applies a transition in one assignment; a banner request becomes the screen's banner.
    private func apply(_ transition: ChildDeletionPresentation.Transition, for childId: String) {
        deletion = transition.presentation
        if let request = transition.banner {
            let result: ChildDeletionResult = switch request {
            case .blocked: .blocked
            case .failed(let error): .failed(error: error)
            }
            showBanner(ChildrenState.banner(for: result), for: childId)
        }
    }

    /// Applies planReady, then re-checks the child list: a child that vanished while planning
    /// must not leave a confirmation with no row to host it. Returns the plan to run, if any.
    private func applyPlanReady(
        childId: String,
        plan: ChildDeletionPlan,
        requiresConfirmation: Bool
    ) -> ChildDeletionPlan? {
        let transition = deletion.planReady(childId: childId, plan: plan, requiresConfirmation: requiresConfirmation)
        apply(transition, for: childId)
        deletion = deletion.childrenChanged(existingIds: childService.children.map(\.id))
        return transition.plan
    }

    private func requestDelete(childId: String) {
        guard deletion.isIdle else { return }
        showBanner(nil, for: childId)
        deletion = deletion.requestDelete(childId: childId)
        announce(ChildrenState.planningAnnouncement)
        startDeletionWork {
            do {
                let plan = try await makeFlow().plan(childId: childId)
                _ = applyPlanReady(childId: childId, plan: plan, requiresConfirmation: true)
            } catch is CancellationError {
                return
            } catch {
                let childError = (error as? ChildError) ?? .server
                apply(deletion.planFailed(childId: childId, error: childError), for: childId)
            }
        }
    }

    private func confirm(childId: String, plan: ChildDeletionPlan) {
        let transition = deletion.confirm(childId: childId, plan: plan)
        deletion = transition.presentation
        guard let confirmedPlan = transition.plan else { return }
        announce(ChildrenState.progressAnnouncement(for: confirmedPlan))
        startDeletionWork {
            let result = await makeFlow().execute(childId: childId, plan: confirmedPlan)
            deletion = deletion.executionFinished(childId: childId)
            finish(result, for: childId)
        }
    }

    /// Try Again: plans afresh and continues without a new dialog. A no-op unless idle.
    private func retryDeletion(_ failure: DeletionFailure) {
        guard deletion.isIdle else { return }
        let childId = failure.childId
        showBanner(nil, for: childId)
        deletion = deletion.requestDelete(childId: childId)
        announce(ChildrenState.planningAnnouncement)
        startDeletionWork {
            let flow = makeFlow()
            let plan: ChildDeletionPlan
            do {
                plan = try await flow.plan(childId: childId)
            } catch is CancellationError {
                return
            } catch {
                let childError = (error as? ChildError) ?? .server
                apply(deletion.planFailed(childId: childId, error: childError), for: childId)
                return
            }
            let planned = applyPlanReady(childId: childId, plan: plan, requiresConfirmation: false)
            guard let planToRun = planned else { return }
            announce(ChildrenState.retryAnnouncement(for: planToRun))
            let result = await flow.execute(childId: childId, plan: planToRun)
            deletion = deletion.executionFinished(childId: childId)
            finish(result, for: childId)
        }
    }
}

// MARK: - Row

/// One child. It holds no state: the screen owns the presentation and passes the dialog's
/// binding and content in. The confirmationDialog is attached here.
private struct ChildRow: View {
    let row: ChildRowState
    @Binding var isConfirmationPresented: Bool
    let confirmation: ChildDeleteConfirmation?
    let confirmingPlan: ChildDeletionPlan?
    let controlsEnabled: Bool
    let onRequestDelete: () -> Void
    let onConfirm: (ChildDeletionPlan) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(row.title)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)
                Text(row.relationshipTitle)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if row.showsProgress {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .listRowBackground(Color.surfaceColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRequestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.destructiveColor)
            .disabled(!controlsEnabled)
        }
        .contextMenu {
            Button(role: .destructive, action: onRequestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.destructiveColor)
            .disabled(!controlsEnabled)
        }
        .accessibilityAction(named: "Delete") {
            if controlsEnabled { onRequestDelete() }
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: $isConfirmationPresented,
            titleVisibility: .visible,
            presenting: confirmation
        ) { confirmation in
            Button(confirmation.confirmButtonTitle, role: .destructive) {
                if let plan = confirmingPlan { onConfirm(plan) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { confirmation in
            Text(confirmation.message)
        }
    }
}

#Preview {
    NavigationStack {
        ChildrenView()
            .environment(\.childService, ChildService(repository: MockChildRepository(listRepository: MockListRepository())))
    }
}
