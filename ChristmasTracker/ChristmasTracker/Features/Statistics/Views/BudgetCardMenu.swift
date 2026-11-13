//
//  BudgetCardMenu.swift
//  ChristmasTracker
//
//  I5a Story C: the menu on the budget card (Edit Budget, Duplicate to Another Year, Delete Budget).
//  The delete confirmation is attached to this menu button, which opens the delete action, and its
//  presented state lives in the screen model above every row. The destructive item and button use
//  role .destructive with the destructive token.
//

import SwiftUI

struct BudgetCardMenu: View {
    @Bindable var model: StatsScreenModel
    let year: Int

    var body: some View {
        Menu {
            Button {
                model.presentEdit()
            } label: {
                Label("Edit Budget", systemImage: "pencil")
            }
            Button {
                model.presentDuplicate()
            } label: {
                Label("Duplicate to Another Year", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                model.requestDelete()
            } label: {
                Label(StatsScreenModel.deleteButtonTitle, systemImage: "trash")
                    .foregroundStyle(Color.destructiveColor)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.appTitle3)
                .frame(
                    minWidth: InlineErrorBannerState.minimumButtonHeight,
                    minHeight: InlineErrorBannerState.minimumButtonHeight
                )
                .contentShape(.rect)
                .accessibilityLabel("Budget options")
        }
        .confirmationDialog(
            StatsScreenModel.deleteTitle(year: year),
            isPresented: $model.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(StatsScreenModel.deleteButtonTitle, role: .destructive) {
                Task { await model.confirmDelete() }
            }
            .tint(Color.destructiveColor)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(StatsScreenModel.deleteMessage)
        }
    }
}

#Preview("Menu") {
    BudgetCardMenu(
        model: StatsScreenModel(
            statsService: StatsService(repository: InertStatsLoader()),
            budgetService: BudgetService(repository: InertBudgetManager()),
            listService: ListService(repository: MockListRepository(), dataStore: ListDataStore()),
            now: { Date() },
            calendar: .current,
            currencyCode: "USD",
            locale: .current
        ),
        year: 2026
    )
    .padding(AppSpacing.lg)
}
