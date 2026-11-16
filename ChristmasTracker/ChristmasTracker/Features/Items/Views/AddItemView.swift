//
//  AddItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// The add form. A creation error is held here, in local state, and shown in an inline banner;
/// it disappears on dismiss, a successful retry, closing the sheet, or leaving the screen.
struct AddItemView: View {
    let listId: String
    let context: ItemListContext

    @Environment(\.itemService) private var itemService
    @Environment(\.listService) private var listService
    @Environment(\.spendingCacheInvalidator) private var spendingCacheInvalidator
    @Environment(\.dismiss) private var dismiss

    /// One locale for the option's total text and for the Record Purchase model that parses it.
    private let formLocale = Locale.current

    @State private var wantsPurchase = true
    @State private var step = OffListPurchaseStep.idle
    @State private var purchaseSheetItem: ListItem?
    /// The prefill captured before the create was sent; the sheet uses only this.
    @State private var purchaseStartingInput: RecordPurchaseFormInput?
    @State private var name = ""
    @State private var description = ""
    @State private var url = ""
    @State private var imageUrl = ""
    @State private var priceText = ""
    @State private var quantityRequested = 1
    @State private var priority = 5
    @State private var imageFill = ItemImageFillModel(mode: .add)
    @State private var isCreating = false
    @State private var creationError: ItemError?

    private var permissions: ItemPermissions {
        ItemPermissions(capabilities: context.capabilities)
    }

    private var input: CreateItemInput? {
        ItemFormValidation.makeCreateInput(
            name: name,
            description: description,
            url: url,
            imageUrl: imageUrl,
            priceText: priceText,
            quantity: quantityRequested,
            priority: priority
        )
    }

    private var option: OffListPurchaseOption {
        OffListPurchaseOption(
            capabilities: context.capabilities,
            mode: .add,
            wantsPurchase: wantsPurchase,
            priceText: priceText,
            quantity: quantityRequested,
            locale: formLocale
        )
    }

    /// True while a create is running or once the item exists: the form is locked.
    private var isLocked: Bool { isCreating || !step.allowsCreate }

    var body: some View {
        NavigationStack {
            Form {
                creationBanner
                ItemFormFields(
                    name: $name,
                    description: $description,
                    url: $url,
                    imageUrl: $imageUrl,
                    priceText: $priceText,
                    quantity: $quantityRequested,
                    priority: $priority,
                    imageFill: imageFill,
                    showsOffListNotice: permissions.showsOffListNotice
                )
                if option.isToggleShown {
                    OffListPurchaseToggleSection(isOn: $wantsPurchase, isDisabled: isLocked)
                }
            }
            .disabled(isLocked)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onDisappear {
                imageFill.cancel()
                creationError = nil
            }
            .sheet(item: $purchaseSheetItem, onDismiss: sheetDismissed) { item in
                purchaseSheet(for: item)
            }
        }
    }

    @ViewBuilder
    private var creationBanner: some View {
        if let banner = creationError.flatMap({ ItemErrorPresentation.banner(for: $0, hasRetryAction: true) }) {
            Section {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await createItem() } },
                    onDismiss: { creationError = nil }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                creationError = nil
                dismiss()
            }
            .disabled(isLocked)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task { await createItem() }
            } label: {
                if isCreating {
                    ProgressView()
                } else {
                    Text("Add")
                }
            }
            .disabled(!option.allowsAdd(formIsValid: input != nil) || isLocked)
        }
    }

    // MARK: - Create

    private func createItem() async {
        guard let input, !isCreating, step.beginCreate() else { return }
        // Snapshot the purchase request now: after the await only this copy is used, so the
        // Record Purchase form always matches what was sent to the server.
        let sentOption = option
        imageFill.cancel()
        creationError = nil
        isCreating = true
        defer { isCreating = false }
        do {
            let item = try await itemService.createItem(listId: listId, input)
            created(item, startingInput: sentOption.isPurchaseRequested ? sentOption.startingInput : nil)
        } catch is CancellationError {
            // The session ended or the task was cancelled: nothing to show.
            step.createFailed()
        } catch {
            step.createFailed()
            let itemError = (error as? ItemError) ?? ItemError.server
            if ItemErrorPresentation.leavesScreen(itemError) {
                dismiss()
            } else {
                creationError = itemError
            }
        }
    }

    /// With a purchase requested and a starting input, the Record Purchase form opens for the new
    /// item; otherwise the form closes as it always did.
    private func created(_ item: ListItem, startingInput: RecordPurchaseFormInput?) {
        let opensPurchase = startingInput != nil
        step.createSucceeded(item, opensPurchase: opensPurchase)
        if opensPurchase {
            purchaseStartingInput = startingInput
            purchaseSheetItem = item
        } else {
            dismiss()
        }
    }

    // MARK: - Purchase sheet

    private func purchaseSheet(for item: ListItem) -> some View {
        RecordPurchaseEnvironmentReader { service in
            RecordPurchaseContent(
                model: RecordPurchaseModel(
                    item: item,
                    context: context,
                    service: service,
                    locale: formLocale,
                    startingInput: purchaseStartingInput
                ),
                onFinish: { finish in finishPurchase(finish, item: item) }
            )
        }
        .interactiveDismissDisabled()
    }

    /// Every finish closes the sheet and the form. A recorded purchase or a check of the item
    /// refreshes the screens afterwards; the runner is built before the form goes away.
    private func finishPurchase(_ finish: RecordPurchaseFinish, item: ListItem) {
        step.purchaseFinished()
        purchaseSheetItem = nil
        let runner = PurchaseRefreshRunner(
            itemService: itemService,
            listService: listService,
            spendingCaches: spendingCacheInvalidator
        )
        dismiss()
        switch finish {
        case .recorded, .checkItem:
            let itemId = item.id
            let itemListId = item.listId
            Task { await runner.runAfterPurchase(itemId: itemId, listId: itemListId) }
        case .itemGone, .cancelled:
            break
        }
    }

    /// A sheet that closes without a finish (not expected, the sheet is not swipe-dismissible)
    /// still ends the form: the item stays created and unpurchased.
    private func sheetDismissed() {
        guard step.pendingItem != nil else { return }
        step.purchaseFinished()
        dismiss()
    }
}

#Preview("Owner") {
    AddItemView(listId: "mock-list-child", context: ItemListContext(capabilities: MockListData.ownerCapabilities))
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
        .environment(\.linkPreviewService, LinkPreviewService(repository: MockLinkPreviewRepository()))
}

#Preview("Member (surprise item)") {
    AddItemView(listId: "mock-list-member", context: ItemListContext(capabilities: MockListData.memberCapabilities))
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
        .environment(\.linkPreviewService, LinkPreviewService(repository: MockLinkPreviewRepository()))
}
