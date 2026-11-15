//
//  PurchaseHistoryPreviews.swift
//  ChristmasTracker
//
//  PH1-H3: previews of the history screen: loaded, first-page loading, empty, no match, first-page
//  failure, next-page failure and large type in dark. The loaders are preview-only and hold fake data.
//

import SwiftUI

/// A preview-only loader that answers every page request with the given closure.
private nonisolated struct PreviewHistoryLoader: PurchaseHistoryLoading {
    let answer: @Sendable (PurchaseHistoryFilter, String?) async throws -> PurchaseHistoryPage

    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage {
        try await answer(filter, cursor)
    }
}

@MainActor
private func previewScreen(
    year: Int = Calendar.current.component(.year, from: Date()),
    recipient: PurchaseHistoryRecipient? = nil,
    loader: any PurchaseHistoryLoading = MockPurchaseHistoryRepository()
) -> some View {
    NavigationStack {
        PurchaseHistoryView(
            route: PurchaseHistoryRoute(year: year, yearChoices: [year, year - 1], recipient: recipient)
        )
    }
    .environment(\.purchaseHistoryService, PurchaseHistoryService(repository: loader))
}

private let previewPerson = PurchaseHistoryRecipient(id: "mock-person-1", name: "Alex Rivera")

#Preview("Loaded") {
    previewScreen()
}

#Preview("Loaded for one person") {
    previewScreen(recipient: previewPerson)
}

#Preview("First page loading") {
    previewScreen(loader: PreviewHistoryLoader { _, _ in
        try await Task.sleep(for: .seconds(3600))
        return PurchaseHistoryPage(rows: [], nextCursor: nil)
    })
}

#Preview("Empty, no purchases yet") {
    previewScreen(loader: PreviewHistoryLoader { _, _ in PurchaseHistoryPage(rows: [], nextCursor: nil) })
}

#Preview("Empty, no match (filters active)") {
    previewScreen(
        recipient: previewPerson,
        loader: PreviewHistoryLoader { _, _ in PurchaseHistoryPage(rows: [], nextCursor: nil) }
    )
}

#Preview("First page failure") {
    previewScreen(loader: PreviewHistoryLoader { _, _ in throw PurchaseHistoryError.network })
}

#Preview("Next page failure") {
    previewScreen(loader: PreviewHistoryLoader { filter, cursor in
        if cursor != nil { throw PurchaseHistoryError.network }
        let page = try await MockPurchaseHistoryRepository().loadPage(filter: filter, cursor: nil)
        return PurchaseHistoryPage(rows: page.rows, nextCursor: page.nextCursor ?? "more")
    })
}

#Preview("Large type, dark") {
    previewScreen()
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
