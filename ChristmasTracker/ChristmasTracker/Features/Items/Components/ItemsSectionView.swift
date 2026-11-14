//
//  ItemsSectionView.swift
//  ChristmasTracker
//
//  The items inside the list detail screen. Driven by `ItemListState` only: the Add button, the
//  sections, the markers and the empty copy all come from the capability flags through the view
//  state. It shows no error of its own: the list detail screen shows one merged banner at its top.
//

import SwiftUI

struct ItemsSectionView: View {
    let state: ItemListState
    let isLoading: Bool
    let onSelect: (String) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
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
        onSelect: { _ in },
        onAdd: { }
    )
    .padding()
}

#Preview("Empty, dark") {
    ItemsSectionView(
        state: ItemListState(items: [], capabilities: MockListData.ownerCapabilities, currentUserId: nil),
        isLoading: false,
        onSelect: { _ in },
        onAdd: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}
