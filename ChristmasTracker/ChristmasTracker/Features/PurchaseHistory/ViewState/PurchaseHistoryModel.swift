//
//  PurchaseHistoryModel.swift
//  ChristmasTracker
//
//  PH1-H2: the logic of the purchase history screen. The view renders this state and sends events. The
//  model pages through the service one request at a time. Every first page load, refresh and filter
//  change takes a new request token; a result whose token is no longer current is dropped without
//  touching state. The model remembers the service's session generation and resets itself when it
//  changed. It knows nothing about navigation or SwiftUI and logs nothing.
//  Known limit: an empty page that still has a cursor is not paged on automatically.
//

import Foundation
import Observation

@MainActor
@Observable
final class PurchaseHistoryModel {

    // MARK: - Types

    enum LoadPhase: Equatable {
        case loading, content, failed
    }

    enum EmptyKind: Equatable {
        case noPurchasesYet, noMatches
    }

    private enum RequestKind {
        case first, refresh, nextPage
    }

    private typealias PageResult = Result<PurchaseHistoryPage, any Error>

    // MARK: - State

    let defaultYear: Int
    private(set) var filter: PurchaseHistoryFilter
    private(set) var rows: [PurchaseHistoryRow] = []
    private(set) var loadPhase: LoadPhase = .loading
    private(set) var isLoadingNextPage = false
    private(set) var isRefreshing = false
    private(set) var nextPageFailed = false
    private(set) var recipientOptions: [PurchaseHistoryRecipient]

    private var nextCursor: String?
    private var lastFailure: LoadFailure?

    /// Counts the loads that ended with a failure, so a new identical failure is a new event.
    private var failureCount = 0
    private var dismissedFailureCount: Int?

    // MARK: - Bookkeeping (not rendered)

    @ObservationIgnored private let service: PurchaseHistoryService
    @ObservationIgnored private let preselectedRecipient: PurchaseHistoryRecipient?
    @ObservationIgnored private var knownGeneration: Int
    @ObservationIgnored private var requestToken = 0
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var inFlightTask: Task<PageResult, Never>?
    @ObservationIgnored private var inFlightKind: RequestKind?

    // MARK: - Initialization

    init(service: PurchaseHistoryService, defaultYear: Int, preselectedRecipient: PurchaseHistoryRecipient? = nil) {
        self.service = service
        self.defaultYear = defaultYear
        self.preselectedRecipient = preselectedRecipient
        self.knownGeneration = service.sessionGeneration
        self.filter = PurchaseHistoryFilter(
            year: defaultYear,
            recipientId: preselectedRecipient?.id,
            shippingStatus: nil
        )
        self.recipientOptions = preselectedRecipient.map { [$0] } ?? []
    }

    // MARK: - Derived state

    var hasActiveFilters: Bool { !filter.isDefault(defaultYear: defaultYear) }

    var emptyKind: EmptyKind? {
        guard loadPhase == .content, rows.isEmpty, nextCursor == nil else { return nil }
        return hasActiveFilters ? .noMatches : .noPurchasesYet
    }

    /// The first page failure with nothing shown: Try Again only.
    var failureBanner: InlineErrorBannerState? {
        guard loadPhase == .failed, let lastFailure else { return nil }
        return PurchaseHistoryFailureBanners.fullError(for: lastFailure)
    }

    /// The refresh failure over saved rows; dismissible.
    var staleBanners: [InlineErrorBannerState] {
        guard loadPhase == .content, let lastFailure, dismissedFailureCount != failureCount else { return [] }
        return PurchaseHistoryFailureBanners.stale(for: lastFailure)
    }

    func dismissStaleBanner() {
        dismissedFailureCount = failureCount
    }

}

// MARK: - Events

extension PurchaseHistoryModel {

    func onAppear() async {
        reconcileSession()
        guard !hasStarted else { return }
        hasStarted = true
        await loadFirstPage(kind: .first)
    }

    func refresh() async {
        reconcileSession()
        hasStarted = true
        await loadFirstPage(kind: .refresh)
    }

    func returnedFromPurchase() async {
        await refresh()
    }

    func tryAgain() async {
        reconcileSession()
        hasStarted = true
        if loadPhase == .failed {
            loadPhase = .loading
            lastFailure = nil
        }
        await loadFirstPage(kind: .refresh)
    }

    func select(year: Int?) async {
        var changed = filter
        changed.year = year
        await change(to: changed)
    }

    func select(shipping: PurchaseShippingStatus?) async {
        var changed = filter
        changed.shippingStatus = shipping
        await change(to: changed)
    }

    func select(recipient: PurchaseHistoryRecipient?) async {
        reconcileSession()
        if let recipient, !recipientOptions.contains(where: { $0.id == recipient.id }) {
            recipientOptions.append(recipient)
        }
        var changed = filter
        changed.recipientId = recipient?.id
        await change(to: changed)
    }

    func clearFilters() async {
        await change(to: PurchaseHistoryFilter(year: defaultYear, recipientId: nil, shippingStatus: nil))
    }

    // MARK: - Paging

    func loadNextPageIfNeeded(currentRowId: String) async {
        reconcileSession()
        guard currentRowId == rows.last?.id, nextCursor != nil, inFlightKind == nil, !nextPageFailed else { return }
        await requestNextPage()
    }

    func retryNextPage() async {
        reconcileSession()
        guard nextCursor != nil, inFlightKind == nil else { return }
        nextPageFailed = false
        await requestNextPage()
    }

    // MARK: - Session

    /// Resets to the initial state when the service's session changed.
    func reconcileSession() {
        let generation = service.sessionGeneration
        guard generation != knownGeneration else { return }
        knownGeneration = generation
        cancelInFlight()
        requestToken += 1
        filter = PurchaseHistoryFilter(year: defaultYear, recipientId: preselectedRecipient?.id, shippingStatus: nil)
        rows = []
        nextCursor = nil
        loadPhase = .loading
        nextPageFailed = false
        lastFailure = nil
        dismissedFailureCount = nil
        hasStarted = false
        recipientOptions = preselectedRecipient.map { [$0] } ?? []
    }

}

// MARK: - Requests

extension PurchaseHistoryModel {

    private func change(to newFilter: PurchaseHistoryFilter) async {
        reconcileSession()
        guard newFilter != filter else { return }
        cancelInFlight()
        filter = newFilter
        rows = []
        nextCursor = nil
        nextPageFailed = false
        lastFailure = nil
        loadPhase = .loading
        hasStarted = true
        await loadFirstPage(kind: .first)
    }

    private func loadFirstPage(kind: RequestKind) async {
        cancelInFlight()
        requestToken += 1
        let token = requestToken
        isRefreshing = kind == .refresh && loadPhase == .content
        nextPageFailed = false
        inFlightKind = kind
        let result = await fetch(filter: filter, cursor: nil)
        guard isCurrent(token) else { return }
        finishRequest()
        switch result {
        case .success(let page):
            rows = page.rows
            nextCursor = page.nextCursor
            loadPhase = .content
            lastFailure = nil
            record(page.rows)
        case .failure(let error):
            noteFirstPageFailure(error)
        }
    }

    private func noteFirstPageFailure(_ error: any Error) {
        if error is CancellationError {
            if loadPhase == .loading { hasStarted = false }
            return
        }
        guard let failure = PurchaseHistoryFailureBanners.failure(for: error) else { return }
        lastFailure = failure
        failureCount += 1
        if rows.isEmpty { loadPhase = .failed }
    }

    private func requestNextPage() async {
        guard let cursor = nextCursor else { return }
        let token = requestToken
        inFlightKind = .nextPage
        isLoadingNextPage = true
        let result = await fetch(filter: filter, cursor: cursor)
        guard isCurrent(token) else { return }
        finishRequest()
        switch result {
        case .success(let page):
            rows += page.rows
            nextCursor = page.nextCursor
            record(page.rows)
        case .failure(let error):
            if !(error is CancellationError) { nextPageFailed = true }
        }
    }

    /// Runs one service call in a task the model can cancel. Cancelling the caller cancels the task too.
    private func fetch(filter: PurchaseHistoryFilter, cursor: String?) async -> PageResult {
        let service = self.service
        let task = Task { @MainActor () -> PageResult in
            do {
                return .success(try await service.loadPage(filter: filter, cursor: cursor))
            } catch {
                return .failure(error)
            }
        }
        inFlightTask = task
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// True when the result of the request with this token may still change state. A session change is
    /// reconciled first, which makes every older token stale.
    private func isCurrent(_ token: Int) -> Bool {
        reconcileSession()
        return token == requestToken
    }

    private func cancelInFlight() {
        inFlightTask?.cancel()
        finishRequest()
    }

    private func finishRequest() {
        inFlightTask = nil
        inFlightKind = nil
        isLoadingNextPage = false
        isRefreshing = false
    }

    private func record(_ newRows: [PurchaseHistoryRow]) {
        for row in newRows where !recipientOptions.contains(where: { $0.id == row.recipientId }) {
            recipientOptions.append(PurchaseHistoryRecipient(id: row.recipientId, name: row.recipientName))
        }
    }
}
