//
//  ListDetailBannersView.swift
//  ChristmasTracker
//
//  UX1a Story U3: the banners at the top of the list detail screen. The load banners (ONE merged banner
//  when the detail and the items fail the same way, two when the categories differ) come from the pure
//  ListDetailLoadState; the action banner is the screen's own mutation failure. Every error is an
//  InlineErrorBanner.
//

import SwiftUI

struct ListDetailBannersView: View {
    let loadBanners: [LoadBanner]
    let actionBanner: InlineErrorBannerState?
    let onRetryLoad: ([LoadSource]) -> Void
    let onDismissLoad: ([LoadSource]) -> Void
    let onRetryAction: () -> Void
    let onDismissAction: () -> Void

    var body: some View {
        ForEach(Array(loadBanners.enumerated()), id: \.offset) { _, banner in
            InlineErrorBanner(
                state: LoadBannerPresentation.state(for: banner),
                onTryAgain: { onRetryLoad(banner.retryTargets) },
                onDismiss: { onDismissLoad(banner.retryTargets) }
            )
        }
        if let actionBanner {
            InlineErrorBanner(
                state: actionBanner,
                onTryAgain: onRetryAction,
                onDismiss: onDismissAction
            )
        }
    }
}

#Preview("Merged stale banner") {
    VStack(spacing: AppSpacing.md) {
        ListDetailBannersView(
            loadBanners: [LoadBanner(message: LoadFailurePolicy.staleDataText, retryTargets: [.listDetail, .items])],
            actionBanner: nil,
            onRetryLoad: { _ in },
            onDismissLoad: { _ in },
            onRetryAction: { },
            onDismissAction: { }
        )
    }
    .padding()
}

#Preview("Two banners and an action error, large type") {
    VStack(spacing: AppSpacing.md) {
        ListDetailBannersView(
            loadBanners: [
                LoadBanner(message: LoadFailurePolicy.staleDataText, retryTargets: [.listDetail]),
                LoadBanner(message: ListError.rateLimited(retryAfter: 30).userMessage, retryTargets: [.items])
            ],
            actionBanner: MutationBanner.state(for: ListError.network),
            onRetryLoad: { _ in },
            onDismissLoad: { _ in },
            onRetryAction: { },
            onDismissAction: { }
        )
    }
    .padding()
    .dynamicTypeSize(.accessibility2)
}
