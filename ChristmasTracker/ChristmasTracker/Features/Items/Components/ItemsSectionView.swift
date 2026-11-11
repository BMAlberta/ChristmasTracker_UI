//
//  ItemsSectionView.swift
//  ChristmasTracker
//
//  The items inside the list detail screen. Driven by `ItemListState` only: the Add button, the
//  sections, the markers and the empty copy all come from the capability flags through the view
//  state. An optional banner shows the load error the screen was handed.
//

import SwiftUI

struct ItemsSectionView: View {
    let state: ItemListState
    let isLoading: Bool
    let errorBanner: InlineErrorBannerState?
    let onSelect: (String) -> Void
    let onAdd: () -> Void
    let onTryAgain: () -> Void
    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            if let errorBanner {
                InlineErrorBanner(state: errorBanner, onTryAgain: onTryAgain, onDismiss: onDismissError)
            }
            if isLoading && state.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            } else if state.isEmpty {
                emptyState
            } else {
                ForEach(state.sections, id: \.title) { section in
                    sectionView(section)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text("Items")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
            Spacer()
            if state.showsAddButton {
                Button(action: onAdd) {
                    Label("Add Item", systemImage: "plus")
                        .font(.appSubheadline)
                        .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .accessibilityIdentifier("listDetail.addItemButton")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "gift.fill")
                .font(.appTitle1)
                .foregroundStyle(Color.textMutedColor)
                .accessibilityHidden(true)
            Text(state.emptyTitle)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
            Text(state.emptyMessage)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    private func sectionView(_ section: ItemSectionState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if state.sections.count > 1 {
                Text(section.title)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textMutedColor)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(section.rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    ItemRow(state: row)
                        .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if row.id != section.rows.first?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview("Owner") {
    ItemsSectionView(
        state: ItemListState(
            items: MockItemSeed.items.filter { $0.listId == "mock-list-child" },
            capabilities: MockListData.ownerCapabilities,
            currentUserId: MockItemRepository.defaultUser.id
        ),
        isLoading: false,
        errorBanner: nil,
        onSelect: { _ in },
        onAdd: { },
        onTryAgain: { },
        onDismissError: { }
    )
    .padding()
}

#Preview("Load error, empty") {
    ItemsSectionView(
        state: ItemListState(items: [], capabilities: MockListData.ownerCapabilities, currentUserId: nil),
        isLoading: false,
        errorBanner: ItemErrorPresentation.banner(for: .network, hasRetryAction: true),
        onSelect: { _ in },
        onAdd: { },
        onTryAgain: { },
        onDismissError: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}
