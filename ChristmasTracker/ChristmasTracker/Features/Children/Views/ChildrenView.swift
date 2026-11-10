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

    @State private var showsAddChild = false
    @State private var childToDelete: Child?
    @State private var actionErrorMessage: String?

    private var state: ChildrenState {
        ChildrenState(children: childService.children, phase: childService.phase)
    }

    var body: some View {
        let state = state
        return List {
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
                ChildRow(row: row, isMutating: childService.isMutating, onDelete: { requestDelete(row) })
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
        .confirmationDialog(
            childToDelete.map { ChildrenState.deleteConfirmation(for: $0).title } ?? "",
            isPresented: Binding(
                get: { childToDelete != nil },
                set: { if !$0 { childToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: childToDelete
        ) { child in
            Button(ChildrenState.deleteConfirmation(for: child).confirmButtonTitle, role: .destructive) {
                Task { await delete(child) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { child in
            Text(ChildrenState.deleteConfirmation(for: child).message)
        }
        .alert(
            "Couldn't remove child",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionErrorMessage ?? "")
        }
        .refreshable {
            await childService.loadChildren()
        }
        .task {
            await childService.loadChildren()
        }
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

    private func requestDelete(_ row: ChildRowState) {
        childToDelete = childService.children.first { $0.id == row.id }
    }

    private func delete(_ child: Child) async {
        do {
            try await childService.deleteChild(id: child.id)
        } catch is CancellationError {
            return
        } catch {
            actionErrorMessage = ((error as? ChildError) ?? .server).userMessage
        }
    }
}

// MARK: - Row

private struct ChildRow: View {
    let row: ChildRowState
    let isMutating: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(row.title)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
            Text(row.relationshipTitle)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .listRowBackground(Color.surfaceColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isMutating)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isMutating)
        }
        .accessibilityAction(named: "Delete", onDelete)
    }
}

#Preview {
    NavigationStack {
        ChildrenView()
            .environment(\.childService, ChildService(repository: MockChildRepository(listRepository: MockListRepository())))
    }
}
