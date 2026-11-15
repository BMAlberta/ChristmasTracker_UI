//
//  ItemAddImageButton.swift
//  ChristmasTracker
//
//  IMG1-P5: the explicit "Add image" action of the Edit form and its failure line. This file is the
//  ONLY place that builds the button and the line, and the only caller of addImageRequested. The
//  Links section shows it on Edit only (the Edit screen is reached through the detail screen's
//  gated Edit button, so no second permission check is made here). While the lookup runs the button
//  is disabled and shows the form's single spinner. A failure shows a quiet line and is announced
//  politely. No URL is logged.
//

import SwiftUI

/// The stateless look of the action, driven by the status so previews need no network.
struct ItemAddImageRow: View {
    let status: ItemAddImageStatus
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button(action: action) {
                HStack(spacing: AppSpacing.sm) {
                    Text(ItemFormCopy.addImageTitle)
                    if status == .running {
                        ProgressView()
                            .accessibilityLabel(ItemFormCopy.lookingForImage)
                    }
                }
            }
            .disabled(!isEnabled || status == .running)
            .accessibilityHint(ItemFormCopy.addImageHint)
            if status == .failed {
                Text(ItemFormCopy.addImageFailure)
                    .appCaption()
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .failed {
                AccessibilityNotification.Announcement(ItemFormCopy.addImageFailure).post()
            }
        }
    }
}

struct ItemAddImageButton: View {
    @Binding var url: String
    @Binding var imageUrl: String
    let imageFill: ItemImageFillModel

    @Environment(\.linkPreviewService) private var linkPreviewService

    var body: some View {
        ItemAddImageRow(
            status: imageFill.addImageStatus,
            isEnabled: imageFill.state.addImageEnabled(url: url, imageUrl: imageUrl),
            action: request
        )
    }

    private func request() {
        let urlBinding = $url
        let imageBinding = $imageUrl
        imageFill.addImageRequested(
            url: url,
            imageUrl: imageUrl,
            service: linkPreviewService,
            current: { (url: urlBinding.wrappedValue, imageUrl: imageBinding.wrappedValue) },
            apply: { imageBinding.wrappedValue = $0 }
        )
    }
}

#Preview("Button") {
    Form { ItemAddImageRow(status: .idle, isEnabled: true, action: {}) }
}

#Preview("Running") {
    Form { ItemAddImageRow(status: .running, isEnabled: false, action: {}) }
}

#Preview("Failed") {
    Form { ItemAddImageRow(status: .failed, isEnabled: true, action: {}) }
}
