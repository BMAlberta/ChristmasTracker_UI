//
//  StatsView.swift
//  ChristmasTracker
//
//  I5a Story C: the Statistics tab. StatsView builds its screen model once from the environment
//  services; StatsContentView renders the model's state (year picker, summary card, budget card,
//  spend by person, banners) and sends events. Sheets use `.sheet(item:)` bound to the model.
//

import SwiftUI

struct StatsView: View {
    @Environment(\.statsService) private var statsService
    @Environment(\.budgetService) private var budgetService
    @Environment(\.listService) private var listService

    // The environment services are not readable in init, so the model is built once, in `.task`,
    // never in `body`. Until then a progress view shows.
    @State private var model: StatsScreenModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    StatsContentView(model: model)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task { buildModelOnce() }
                }
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Statistics")
        }
    }

    private func buildModelOnce() {
        guard model == nil else { return }
        model = StatsScreenModel(
            statsService: statsService,
            budgetService: budgetService,
            listService: listService,
            now: { Date() },
            calendar: .current,
            currencyCode: "USD",
            locale: .current
        )
    }
}

struct StatsContentView: View {
    @Bindable var model: StatsScreenModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(Array(model.staleBanners.enumerated()), id: \.offset) { _, stale in
                    InlineErrorBanner(
                        state: stale,
                        onTryAgain: { Task { await model.tryAgain() } },
                        onDismiss: { model.dismissStaleBanner() }
                    )
                }
                phaseContent
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .refreshable { await model.refresh() }
        .onAppear { Task { await model.onAppear() } }
        .onDisappear { model.onDisappear() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StatsYearPicker(model: model)
            }
        }
        .sheet(item: $model.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.loadPhase {
        case .loading:
            ProgressView("Loading statistics...")
                .frame(maxWidth: .infinity)
        case .failed:
            if let failure = model.failureBanner {
                InlineErrorBanner(state: failure, onTryAgain: { Task { await model.tryAgain() } })
            }
        case .content:
            if let state = model.screenState {
                StatsStateView(model: model, state: state)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: StatsScreenModel.Sheet) -> some View {
        switch sheet {
        case .create, .edit:
            if let editor = model.makeEditorModel(for: sheet) {
                BudgetEditorView(model: editor) { saved in
                    Task { await model.didSave(saved) }
                }
            }
        case .duplicate(let budget):
            DuplicateBudgetView(model: model.makeDuplicateModel(for: budget)) { copy in
                Task { await model.didDuplicate(copy) }
            }
        }
    }
}

/// The cards of one year, from the screen state.
private struct StatsStateView: View {
    @Bindable var model: StatsScreenModel
    let state: StatsScreenState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let summary = state.summary {
                StatsSummaryCardView(summary: summary)
            }
            if let card = state.budgetCard {
                BudgetCardView(model: model, card: card)
            }
            if let noBudget = state.noBudgetTitle {
                NoBudgetCardView(title: noBudget, createTitle: model.createBudgetTitle) {
                    model.presentCreate()
                }
            }
            if let empty = state.emptyMessage {
                emptyCard(empty)
            }
            if state.kind != .nothing {
                SpendByPersonView(rows: state.spendRows)
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(text)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .fixedSize(horizontal: false, vertical: true)
            CreateBudgetButton(title: model.createBudgetTitle) {
                model.presentCreate()
            }
        }
        .statsCardStyle()
    }
}

/// The year picker menu of the toolbar.
private struct StatsYearPicker: View {
    @Bindable var model: StatsScreenModel

    var body: some View {
        Menu {
            Picker("Year", selection: yearBinding) {
                ForEach(model.yearChoices, id: \.self) { year in
                    Text(verbatim: String(year)).tag(year)
                }
            }
        } label: {
            Label(String(model.selectedYear), systemImage: "calendar")
                .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .accessibilityLabel("Year")
        .accessibilityValue(String(model.selectedYear))
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { model.selectedYear },
            set: { year in Task { await model.select(year: year) } }
        )
    }
}

#Preview("Statistics, mock data") {
    let store = MockBudgetStore(currentYear: Calendar.current.component(.year, from: Date()))
    StatsView()
        .environment(\.statsService, StatsService(repository: MockStatsRepository(store: store)))
        .environment(\.budgetService, BudgetService(repository: MockBudgetRepository(store: store)))
}

#Preview("Statistics, large type, dark") {
    let store = MockBudgetStore(currentYear: Calendar.current.component(.year, from: Date()))
    StatsView()
        .environment(\.statsService, StatsService(repository: MockStatsRepository(store: store)))
        .environment(\.budgetService, BudgetService(repository: MockBudgetRepository(store: store)))
        .dynamicTypeSize(.accessibility2)
        .preferredColorScheme(.dark)
}
