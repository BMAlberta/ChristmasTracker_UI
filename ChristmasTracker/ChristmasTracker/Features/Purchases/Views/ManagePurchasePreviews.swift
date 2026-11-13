//
//  ManagePurchasePreviews.swift
//  ChristmasTracker
//
//  Previews of the purchase detail: light, dark and large type. They run over the mock purchase
//  manager seeded with one fake purchase of the preview user. Mock data only.
//

import SwiftUI

@MainActor
private enum ManagePurchasePreviewSupport {
    nonisolated static let buyer = ListItemPerson(id: "preview-buyer", displayName: "Sam Buyer")
    nonisolated static let recipient = ListItemPerson(id: "preview-recipient", displayName: "Pat Recipient")

    nonisolated static func purchase() -> RecordedPurchase {
        RecordedPurchase(
            id: "preview-purchase",
            itemId: "preview-item",
            quantity: 2,
            totalCost: Decimal(4250) / 100,
            storeName: "Fake Store",
            notes: "Wrap in blue paper",
            confirmationNumber: "CONF-PREVIEW-1",
            trackingNumber: nil,
            shippingStatus: .notTracked,
            shippedAt: nil,
            deliveredAt: nil,
            purchaser: buyer,
            recipient: recipient,
            item: PurchaseItemReference(id: "preview-item", name: "Fake Lamp", listId: "preview-list"),
            purchasedAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func model() -> PurchaseDetailModel {
        let store = MockPurchaseStore(seed: [purchase()])
        let buyerId = buyer.id
        let service = PurchaseService(
            repository: MockPurchaseRecorder(access: { _ in .forbidden }, store: store),
            management: MockPurchaseManager(store: store, currentUserId: { buyerId })
        )
        return PurchaseDetailModel(
            purchaseId: "preview-purchase",
            itemId: "preview-item",
            listId: "preview-list",
            currentUserId: buyerId,
            service: service,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US")
        )
    }
}

#Preview("Light") {
    NavigationStack {
        ManagePurchaseContent(model: ManagePurchasePreviewSupport.model(), onFinish: { _ in })
    }
}

#Preview("Dark") {
    NavigationStack {
        ManagePurchaseContent(model: ManagePurchasePreviewSupport.model(), onFinish: { _ in })
    }
    .preferredColorScheme(.dark)
}

#Preview("Large type") {
    NavigationStack {
        ManagePurchaseContent(model: ManagePurchasePreviewSupport.model(), onFinish: { _ in })
    }
    .dynamicTypeSize(.accessibility3)
}
