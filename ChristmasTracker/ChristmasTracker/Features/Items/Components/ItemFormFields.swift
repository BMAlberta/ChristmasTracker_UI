//
//  ItemFormFields.swift
//  ChristmasTracker
//
//  The form sections shared by the Add and Edit screens. There is no offList control anywhere:
//  the server derives the item type from the caller. The one plain sentence about a hidden
//  (surprise) item is shown only when the caller passes `showsOffListNotice`, which comes from
//  `ItemPermissions.showsOffListNotice`.
//

import SwiftUI

struct ItemFormFields: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var url: String
    @Binding var imageUrl: String
    @Binding var priceText: String
    @Binding var quantity: Int
    @Binding var priority: Int
    var showsOffListNotice = false

    private var priceLooksInvalid: Bool {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && ItemFormValidation.parsePrice(trimmed) == nil
    }

    var body: some View {
        Section("Item Details") {
            TextField("Item Name", text: $name)
                .autocorrectionDisabled()
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...6)
        }
        Section("Links") {
            TextField("URL (optional)", text: $url)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            TextField("Image URL (optional)", text: $imageUrl)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
        }
        Section("Pricing") {
            HStack {
                Text("$")
                TextField("Price (optional)", text: $priceText)
                    .keyboardType(.decimalPad)
            }
            if priceLooksInvalid {
                Text(ItemError.invalidPrice.userMessage)
                    .font(.appCaption1)
                    .foregroundStyle(Color.destructiveColor)
            }
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
        }
        Section("Priority") {
            Stepper("Priority: \(priority)", value: $priority, in: 1...10)
            Text("1 = Low priority, 10 = High priority")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
        if showsOffListNotice {
            Section {
                Label(ItemFormCopy.offListSentence, systemImage: "gift.fill")
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
        }
    }
}
