//
//  RecordPurchasePreviews.swift
//  ChristmasTracker
//
//  Previews of the Record Purchase form: editing, over-purchase, awaiting confirmation (one
//  recipient and one total warning), expired and error. Mock data only.
//

import SwiftUI

@MainActor
private enum RecordPurchasePreviewSupport {
    nonisolated static let recipient = ListItemPerson(id: "preview-recipient", displayName: "Pat Recipient")

    static func item(remaining: Int?) -> ListItem {
        ListItem(
            id: "preview-item",
            listId: "preview-list",
            name: "Fake Lamp",
            description: "A lamp for previews",
            expectedUnitPrice: 19.99,
            quantityRequested: 3,
            priority: 2,
            status: .available,
            offList: false,
            createdBy: recipient,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            quantityRemaining: remaining
        )
    }

    static let buyerContext = ItemListContext(capabilities: MockListData.memberCapabilities)

    /// `denied` makes the mock answer 403, for the error preview.
    static func model(remaining: Int?, denied: Bool = false) -> RecordPurchaseModel {
        let access: MockPurchaseAccess = denied ? .forbidden : .allowed(recipient: recipient)
        return RecordPurchaseModel(
            item: item(remaining: remaining),
            context: buyerContext,
            service: PurchaseService(repository: MockPurchaseRecorder(access: { _ in access }))
        )
    }
}

/// Fills the form and taps Record once, so the preview shows the state that follows.
private struct DrivenRecordPurchasePreview: View {
    @State private var model: RecordPurchaseModel
    private let cost: String

    init(model: RecordPurchaseModel, cost: String) {
        _model = State(initialValue: model)
        self.cost = cost
    }

    var body: some View {
        RecordPurchaseContent(model: model, onFinish: { _ in })
            .task {
                model.input.totalCostText = cost
                await model.recordTapped()
            }
    }
}

#Preview("Editing") {
    RecordPurchaseContent(model: RecordPurchasePreviewSupport.model(remaining: 3), onFinish: { _ in })
}

#Preview("Over-purchase (nothing remains)") {
    let model = RecordPurchasePreviewSupport.model(remaining: 0)
    model.input.totalCostText = "19.99"
    return RecordPurchaseContent(model: model, onFinish: { _ in })
}

#Preview("Awaiting confirmation (recipient and total warning)") {
    DrivenRecordPurchasePreview(model: RecordPurchasePreviewSupport.model(remaining: 3), cost: "90.00")
}

#Preview("Expired") {
    Form {
        Section {
            RecordPurchaseExpiredNotice(onEdit: {})
        }
    }
}

#Preview("Error") {
    DrivenRecordPurchasePreview(
        model: RecordPurchasePreviewSupport.model(remaining: 3, denied: true),
        cost: "19.99"
    )
}
