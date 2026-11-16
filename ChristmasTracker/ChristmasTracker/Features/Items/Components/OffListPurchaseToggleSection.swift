//
//  OffListPurchaseToggleSection.swift
//  ChristmasTracker
//
//  The "I already bought this" choice on the Add Item form. The caller decides whether it is shown
//  (OffListPurchaseOption.isToggleShown); this view only draws the toggle and its footer.
//

import SwiftUI

struct OffListPurchaseToggleSection: View {
    @Binding var isOn: Bool
    let isDisabled: Bool

    var body: some View {
        Section {
            Toggle("I already bought this", isOn: $isOn)
                .font(.appBody)
                .disabled(isDisabled)
                .accessibilityHint("Opens the purchase form after you add the item")
        } footer: {
            if isOn {
                Text("You'll review the purchase next. It needs a price.")
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
        }
    }
}

#Preview("On") {
    Form {
        OffListPurchaseToggleSection(isOn: .constant(true), isDisabled: false)
    }
}

#Preview("Off") {
    Form {
        OffListPurchaseToggleSection(isOn: .constant(false), isDisabled: false)
    }
}
