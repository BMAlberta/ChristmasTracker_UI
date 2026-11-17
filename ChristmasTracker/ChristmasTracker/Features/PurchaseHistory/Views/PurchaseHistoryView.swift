//
//  PurchaseHistoryView.swift
//  ChristmasTracker
//
//  PH1-H3: the Purchase History screen, pushed from Statistics. It builds its model once from the
//  environment service (never in `body`), renders the model's state (filters, banners, rows, empty
//  states, the paging footer) and sends events. A row opens the existing ManagePurchaseView; when it
//  closes, by finishing or by the back button, the first page is refreshed.
//

import SwiftUI

struct PurchaseHistoryView: View {
    let route: PurchaseHistoryRoute

    @Environment(\.purchaseHistoryService) private var service
    @Environment(\.authenticationService) private var authenticationService

    // The environment service is not readable in init, so the model is built once, in `.task`.
    @State private var model: PurchaseHistoryModel?
    @State private var openedPurchase: OpenedPurchase?

    /// The purchase pushed from a row. It carries its own ids, so the pushed screen does not depend on
    /// the row staying in the list while this screen is covered.
    private struct OpenedPurchase: Hashable {
        let purchaseId: String
        let itemId: String
        let listId: String
    }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { buildModelOnce() }
            }
        }
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("Purchase History")
        .navigationDestination(item: $openedPurchase) { opened in
            ManagePurchaseView(
                purchaseId: opened.purchaseId,
                itemId: opened.itemId,
                listId: opened.listId,
                currentUserId: authenticationService.currentUser?.id,
                onFinish: { _ in openedPurchase = nil }
            )
        }
        .onChange(of: openedPurchase) { previous, current in
            if previous != nil, current == nil, let model {
                Task { await model.returnedFromPurchase() }
            }
        }
    }

    private func buildModelOnce() {
        guard model == nil else { return }
        model = PurchaseHistoryModel(
            service: service,
            defaultYear: route.year,
            preselectedRecipient: route.recipient
        )
    }

    // MARK: - Content

    private func content(_ model: PurchaseHistoryModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                PurchaseHistoryFilterBar(
                    model: model,
                    yearChoices: route.yearChoices,
                    showsClearButton: model.emptyKind != .noMatches
                )
                ForEach(Array(model.staleBanners.enumerated()), id: \.offset) { _, stale in
                    InlineErrorBanner(
                        state: stale,
                        onTryAgain: { Task { await model.refresh() } },
                        onDismiss: { model.dismissStaleBanner() }
                    )
                }
                phaseContent(model)
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .refreshable { await model.refresh(reason: .pull) }
        .task { await model.onAppear() }
        .onChange(of: service.sessionGeneration) {
            model.reconcileSession()
            Task { await model.onAppear(reason: .session) }
        }
    }

    @ViewBuilder
    private func phaseContent(_ model: PurchaseHistoryModel) -> some View {
        switch model.loadPhase {
        case .loading:
            ProgressView("Loading purchases...")
                .frame(maxWidth: .infinity)
        case .failed:
            if let failure = model.failureBanner {
                InlineErrorBanner(state: failure, onTryAgain: { Task { await model.tryAgain() } })
            }
        case .content:
            if let kind = model.emptyKind {
                emptyState(kind, model)
            } else {
                rows(model)
            }
        }
    }

    // MARK: - Empty states

    @ViewBuilder
    private func emptyState(_ kind: PurchaseHistoryModel.EmptyKind, _ model: PurchaseHistoryModel) -> some View {
        switch kind {
        case .noPurchasesYet:
            EmptyStateView(
                icon: "bag",
                title: "No purchases yet.",
                message: "Purchases you record will show up here."
            )
        case .noMatches:
            EmptyStateView(
                icon: "line.3.horizontal.decrease.circle",
                title: "No purchases match these filters.",
                message: "Try a different year, person or shipping status.",
                actionTitle: "Clear filters",
                action: { Task { await model.clearFilters() } }
            )
        }
    }

    // MARK: - Rows and footer

    @ViewBuilder
    private func rows(_ model: PurchaseHistoryModel) -> some View {
        ForEach(model.rows) { row in
            PurchaseHistoryRowView(row: row) {
                openedPurchase = OpenedPurchase(purchaseId: row.id, itemId: row.itemId, listId: row.listId)
            }
            .onAppear {
                Task { await model.loadNextPageIfNeeded(currentRowId: row.id) }
            }
        }
        footer(model)
    }

    @ViewBuilder
    private func footer(_ model: PurchaseHistoryModel) -> some View {
        if model.isLoadingNextPage {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if model.nextPageFailed {
            Button {
                Task { await model.retryNextPage() }
            } label: {
                Text("Couldn't load more. Try again.")
                    .font(.appCallout)
                    .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
            }
            .buttonStyle(.bordered)
        }
    }
}
