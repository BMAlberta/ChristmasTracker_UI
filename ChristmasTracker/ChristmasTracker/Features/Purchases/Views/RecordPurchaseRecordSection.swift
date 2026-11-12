//
//  RecordPurchaseRecordSection.swift
//  ChristmasTracker
//
//  The Record button of the form. It carries the one confirmation dialog of the purchase views:
//  the soft over-purchase prompt ("Record anyway?"), which never blocks a purchase.
//

import SwiftUI

struct RecordPurchaseRecordSection: View {
    @Bindable var model: RecordPurchaseModel

    var body: some View {
        Section {
            Button {
                Task { await model.recordTapped() }
            } label: {
                HStack {
                    if model.isSubmitting {
                        ProgressView()
                    }
                    Text(model.isSubmitting ? "Recording..." : "Record Purchase")
                        .font(.appHeadline)
                }
                .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryColor)
            .disabled(!model.canTapRecord)
            .confirmationDialog(
                model.overPurchasePrompt?.title ?? "",
                isPresented: $model.isShowingOverPurchasePrompt,
                titleVisibility: .visible
            ) {
                Button(model.overPurchasePrompt?.confirmButtonTitle ?? "Continue Anyway") {
                    Task { await model.confirmOverPurchase() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(model.overPurchasePrompt?.message ?? "")
            }
        }
    }
}
