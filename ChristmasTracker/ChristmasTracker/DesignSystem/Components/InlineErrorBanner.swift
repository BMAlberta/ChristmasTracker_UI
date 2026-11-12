//
//  InlineErrorBanner.swift
//  ChristmasTracker
//
//  An error shown in place: the icon and the wrapping message on top, the actions below,
//  left-aligned in the fixed order Try Again then Dismiss. The buttons stack when they do not
//  fit (large Dynamic Type). The icon and message are one accessibility element and the
//  message is announced when the banner appears.
//

import SwiftUI

struct InlineErrorBanner: View {
    let state: InlineErrorBannerState
    var onTryAgain: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onCheckItem: (() -> Void)?
    var onRecordAgain: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        state: InlineErrorBannerState,
        onTryAgain: (() -> Void)? = nil,
        onCheckItem: (() -> Void)? = nil,
        onRecordAgain: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.state = state
        self.onTryAgain = onTryAgain
        self.onCheckItem = onCheckItem
        self.onRecordAgain = onRecordAgain
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            messageRow
            if !state.actions.isEmpty {
                buttonRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets.appCardPadding)
        .background(Color.destructiveColor.opacity(0.12), in: .rect(cornerRadius: AppSpacing.md))
        .onAppear {
            AccessibilityNotification.Announcement(state.announcement).post()
        }
    }

    private var messageRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.destructiveColor)
            Text(state.message)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    @ViewBuilder
    private var buttonRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                buttons
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.md) {
                    buttons
                }
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    buttons
                }
            }
        }
    }

    private var buttons: some View {
        ForEach(state.actions, id: \.title) { action in
            Button {
                perform(action)
            } label: {
                Text(action.title)
                    .font(.appHeadline)
                    .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
            }
            .buttonStyle(.bordered)
            .tint(Color.primaryColor)
        }
    }

    private func perform(_ action: InlineErrorBannerAction) {
        switch action {
        case .tryAgain: onTryAgain?()
        case .dismiss: onDismiss?()
        case .checkItem: onCheckItem?()
        case .recordAgain: onRecordAgain?()
        }
    }
}

#Preview("Try Again and Dismiss") {
    InlineErrorBanner(
        state: InlineErrorBannerState(message: "Couldn't reach the server.", canRetry: true, isDismissible: true)
    )
    .padding()
}

#Preview("Dark") {
    InlineErrorBanner(
        state: InlineErrorBannerState(message: "You don't have permission to do that.", canRetry: false, isDismissible: true)
    )
    .padding()
    .background(Color.backgroundPrimaryColor)
    .preferredColorScheme(.dark)
}

#Preview("Large type") {
    InlineErrorBanner(
        state: InlineErrorBannerState(
            message: "The server had a problem. Please try again in a moment.",
            canRetry: true,
            isDismissible: true
        )
    )
    .padding()
    .dynamicTypeSize(.accessibility3)
}
