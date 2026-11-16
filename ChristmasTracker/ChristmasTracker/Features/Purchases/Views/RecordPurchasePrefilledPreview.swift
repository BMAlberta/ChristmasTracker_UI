//
//  RecordPurchasePrefilledPreview.swift
//  ChristmasTracker
//
//  Preview of the Record Purchase form as the Add Item form opens it: quantity and total already
//  filled in (3 x 12.50). Mock data only.
//

import SwiftUI

#Preview("Prefilled from the Add Item form") {
    let recipient = ListItemPerson(id: "preview-recipient", displayName: "Pat Recipient")
    let item = ListItem(
        id: "preview-item",
        listId: "preview-list",
        name: "Fake Scarf",
        description: "",
        expectedUnitPrice: 12.50,
        quantityRequested: 3,
        priority: 5,
        status: .available,
        offList: true,
        createdBy: recipient,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        canEdit: true,
        canDelete: true,
        quantityRemaining: 3
    )
    let start = OffListPurchaseOption(
        capabilities: MockListData.memberCapabilities,
        mode: .add,
        wantsPurchase: true,
        priceText: "12.50",
        quantity: 3
    ).startingInput
    let model = RecordPurchaseModel(
        item: item,
        context: ItemListContext(capabilities: MockListData.memberCapabilities),
        service: PurchaseService(repository: MockPurchaseRecorder(access: { _ in .allowed(recipient: recipient) })),
        startingInput: start
    )
    return RecordPurchaseContent(model: model, onFinish: { _ in })
}
