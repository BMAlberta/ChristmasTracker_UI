//
//  PurchaseHistoryFilterBar.swift
//  ChristmasTracker
//
//  PH1-H3: the Year, Shipping and Recipient menus and the Clear filters button. Each menu holds a
//  picker that sends the choice to the model. At accessibility Dynamic Type sizes the menus stack;
//  otherwise they sit in a horizontally scrolling row.
//

import SwiftUI

struct PurchaseHistoryFilterBar: View {
    let model: PurchaseHistoryModel
    let yearChoices: [Int]
    var showsClearButton = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            menuLayout
            if showsClearButton && model.hasActiveFilters {
                Button {
                    Task { await model.clearFilters() }
                } label: {
                    Text("Clear filters")
                        .font(.appHeadline)
                        .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var menuLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                menus
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    menus
                }
            }
        }
    }

    @ViewBuilder
    private var menus: some View {
        yearMenu
        shippingMenu
        recipientMenu
    }

    // MARK: - Menus

    private var yearMenu: some View {
        Menu {
            Picker(PurchaseHistoryScreenState.yearAccessibilityLabel, selection: yearBinding) {
                ForEach(
                    PurchaseHistoryScreenState.yearOptions(choices: yearChoices, selected: model.filter.year)
                ) { option in
                    Text(option.title).tag(option.value)
                }
            }
        } label: {
            menuLabel(PurchaseHistoryScreenState.yearTitle(model.filter.year))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(PurchaseHistoryScreenState.yearAccessibilityLabel)
        .accessibilityValue(PurchaseHistoryScreenState.yearAccessibilityValue(model.filter.year))
    }

    private var shippingMenu: some View {
        Menu {
            Picker(PurchaseHistoryScreenState.shippingAccessibilityLabel, selection: shippingBinding) {
                ForEach(PurchaseHistoryScreenState.shippingOptions()) { option in
                    Text(option.title).tag(option.value)
                }
            }
        } label: {
            menuLabel(PurchaseHistoryScreenState.shippingTitle(model.filter.shippingStatus))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(PurchaseHistoryScreenState.shippingAccessibilityLabel)
        .accessibilityValue(PurchaseHistoryScreenState.shippingAccessibilityValue(model.filter.shippingStatus))
    }

    private var recipientMenu: some View {
        let people = model.recipientOptions
        let selectedId = model.filter.recipientId
        return Menu {
            Picker(PurchaseHistoryScreenState.recipientAccessibilityLabel, selection: recipientBinding) {
                ForEach(PurchaseHistoryScreenState.recipientOptions(people)) { option in
                    Text(option.title).tag(option.value)
                }
            }
        } label: {
            menuLabel(PurchaseHistoryScreenState.recipientTitle(recipientId: selectedId, people: people))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(PurchaseHistoryScreenState.recipientAccessibilityLabel)
        .accessibilityValue(
            PurchaseHistoryScreenState.recipientAccessibilityValue(recipientId: selectedId, people: people)
        )
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(.appCallout)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down")
                .font(.appCaption1)
                .accessibilityHidden(true)
        }
        .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
    }

    // MARK: - Bindings (the model decides; the picker only reports the choice)

    private var yearBinding: Binding<Int?> {
        Binding(
            get: { model.filter.year },
            set: { year in Task { await model.select(year: year) } }
        )
    }

    private var shippingBinding: Binding<PurchaseShippingStatus?> {
        Binding(
            get: { model.filter.shippingStatus },
            set: { status in Task { await model.select(shipping: status) } }
        )
    }

    private var recipientBinding: Binding<PurchaseHistoryRecipient?> {
        Binding(
            get: { model.recipientOptions.first { $0.id == model.filter.recipientId } },
            set: { person in Task { await model.select(recipient: person) } }
        )
    }
}
