//
//  ItemLinksSection.swift
//  ChristmasTracker
//
//  IMG1-P3: the Links section of the item form, shared by Add and Edit. It is the ONE place that
//  triggers the link-preview lookup: when focus leaves the URL field and when it is submitted
//  (never per keystroke). The image field reports every text change to the model so a typed value
//  is never overwritten. A spinner shows while a lookup runs and a small decorative thumbnail shows
//  when the image text is not blank. The invalid-value lines come from ItemFormValidation; on Edit
//  an unchanged stored value shows nothing. No URL is logged.
//

import SwiftUI

struct ItemLinksSection: View {
    @Binding var url: String
    @Binding var imageUrl: String
    let imageFill: ItemImageFillModel
    /// The stored values on Edit (nil on Add), so an unchanged legacy value shows no message.
    var originalUrl: String?
    var originalImageUrl: String?

    @Environment(\.linkPreviewService) private var linkPreviewService
    @FocusState private var urlFocused: Bool

    private var validity: ItemFormValidity {
        ItemFormValidation.validate(
            name: "x", description: "x", url: url, imageUrl: imageUrl,
            priceText: "", quantity: 1, priority: 1,
            originalUrl: originalUrl, originalImageUrl: originalImageUrl
        )
    }

    private var imageTextBinding: Binding<String> {
        Binding(
            get: { imageUrl },
            set: { newValue in
                imageUrl = newValue
                imageFill.imageTextChanged(to: newValue)
            }
        )
    }

    private var trimmedImageUrl: String {
        imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Section("Links") {
            TextField("URL (optional)", text: $url)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.done)
                .focused($urlFocused)
                .onSubmit { startLookup() }
                .onChange(of: urlFocused) { wasFocused, isFocused in
                    if wasFocused && !isFocused { startLookup() }
                }
            if validity.urlInvalid {
                invalidLine(ItemFormCopy.invalidUrl)
            }
            HStack(spacing: AppSpacing.sm) {
                TextField("Image URL (optional)", text: imageTextBinding)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                if imageFill.isLooking {
                    ProgressView()
                        .accessibilityLabel(ItemFormCopy.lookingForImage)
                }
                if !trimmedImageUrl.isEmpty {
                    ItemThumbnail(imageUrl: trimmedImageUrl)
                }
            }
            if validity.imageUrlInvalid {
                invalidLine(ItemFormCopy.invalidImageUrl)
            }
        }
    }

    private func invalidLine(_ text: String) -> some View {
        Text(text)
            .font(.appCaption1)
            .foregroundStyle(Color.destructiveColor)
    }

    private func startLookup() {
        let applyBinding = $imageUrl
        let urlBinding = $url
        imageFill.urlEditingFinished(
            url: url,
            imageUrl: imageUrl,
            service: linkPreviewService,
            current: { (url: urlBinding.wrappedValue, imageUrl: applyBinding.wrappedValue) },
            apply: { applyBinding.wrappedValue = $0 }
        )
    }
}

#Preview("Links") {
    @Previewable @State var url = "https://\(MockLinkPreviewRepository.knownHost)/p/1"
    @Previewable @State var imageUrl = ""
    Form {
        ItemLinksSection(url: $url, imageUrl: $imageUrl, imageFill: ItemImageFillModel(mode: .add))
    }
    .environment(\.linkPreviewService, LinkPreviewService(repository: MockLinkPreviewRepository()))
}
