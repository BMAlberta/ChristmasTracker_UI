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
    @State private var deletingChildId: String?
    @State private var deletionFailure: DeletionFailure?
    @State private var deletionTask: Task<Void, Never>?

    /// A deletion that did not remove the child, held only in this screen's state.
    private struct DeletionFailure: Equatable {
        let childId: String
        let banner: ChildDeletionBanner
    }

    private var state: ChildrenState {
        ChildrenState(children: childService.children, phase: childService.phase, deletingChildId: deletingChildId)
    }

    var body: some View {
        let state = state
        let controlsEnabled = ChildrenState.deleteControlsEnabled(
            isMutating: childService.isMutating,
            deletingChildId: deletingChildId
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
                        child: child,
                        controlsEnabled: controlsEnabled,
                        deletingChildId: $deletingChildId,
                        start: startDeletionWork,
                        onBanner: { showBanner($0, for: row.id) },
                        onResult: { finish($0, for: row.id) }
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
        .onDisappear {
            deletionTask?.cancel()
            deletionTask = nil
            deletingChildId = nil
        }
    }

    // MARK: - Deletion banner

    private func deletionBanner(_ failure: DeletionFailure) -> some View {
        InlineErrorBanner(
            state: failure.banner.state,
            onTryAgain: { retry(failure) },
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

    private func retry(_ failure: DeletionFailure) {
        let childId = failure.childId
        startDeletionWork {
            deletingChildId = childId
            AccessibilityNotification.Announcement(
                ChildrenState.progressAnnouncement(for: .archiveThenDelete(listIds: []))
            ).post()
            let flow = ChildDeletionFlow(childService: childService, listService: listService)
            let result = await flow.run(childId: childId)
            deletingChildId = nil
            finish(result, for: childId)
        }
    }
}

// MARK: - Row

/// One child. It holds its own confirmation state, so the confirmationDialog is attached here.
private struct ChildRow: View {
    let row: ChildRowState
    let child: Child
    let controlsEnabled: Bool
    @Binding var deletingChildId: String?
    let start: (@escaping @MainActor () async -> Void) -> Void
    let onBanner: (ChildDeletionBanner?) -> Void
    let onResult: (ChildDeletionResult?) -> Void

    @Environment(\.childService) private var childService
    @Environment(\.listService) private var listService

    @State private var pendingPlan: ChildDeletionPlan?
    @State private var showsConfirmation = false

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
            if row.isDeleting {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .listRowBackground(Color.surfaceColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: requestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.destructiveColor)
            .disabled(!controlsEnabled)
        }
        .contextMenu {
            Button(role: .destructive, action: requestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.destructiveColor)
            .disabled(!controlsEnabled)
        }
        .accessibilityAction(named: "Delete") {
            if controlsEnabled { requestDelete() }
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: $showsConfirmation,
            titleVisibility: .visible,
            presenting: confirmation
        ) { confirmation in
            Button(confirmation.confirmButtonTitle, role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) { }
        } message: { confirmation in
            Text(confirmation.message)
        }
    }

    private var confirmation: ChildDeleteConfirmation? {
        pendingPlan.flatMap { ChildrenState.deleteConfirmation(for: child, plan: $0) }
    }

    private func makeFlow() -> ChildDeletionFlow {
        ChildDeletionFlow(childService: childService, listService: listService)
    }

    private func requestDelete() {
        guard controlsEnabled else { return }
        let childId = row.id
        start {
            onBanner(nil)
            deletingChildId = childId
            defer { deletingChildId = nil }
            do {
                let plan = try await makeFlow().plan(childId: childId)
                if plan == .blocked {
                    onBanner(ChildrenState.banner(for: .blocked))
                } else {
                    pendingPlan = plan
                    showsConfirmation = true
                }
            } catch is CancellationError {
                return
            } catch {
                let childError = (error as? ChildError) ?? .server
                onBanner(ChildrenState.banner(for: .failed(error: childError)))
            }
        }
    }

    private func confirmDelete() {
        guard let plan = pendingPlan else { return }
        pendingPlan = nil
        let childId = row.id
        start {
            deletingChildId = childId
            AccessibilityNotification.Announcement(ChildrenState.progressAnnouncement(for: plan)).post()
            let result = await makeFlow().execute(childId: childId, plan: plan)
            deletingChildId = nil
            onResult(result)
        }
    }
}

#Preview {
    NavigationStack {
        ChildrenView()
            .environment(\.childService, ChildService(repository: MockChildRepository(listRepository: MockListRepository())))
    }
}
