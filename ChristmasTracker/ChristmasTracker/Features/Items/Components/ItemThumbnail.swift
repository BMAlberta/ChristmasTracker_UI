//
//  ItemThumbnail.swift
//  ChristmasTracker
//
//  Story TH1-T6: a decorative item thumbnail. A valid https value loads through AsyncImage; a
//  missing, invalid or failed image shows one shared placeholder. Nothing here logs the value.
//

import SwiftUI

struct ItemThumbnail: View {
    let imageUrl: String?

    @ScaledMetric(relativeTo: .body) private var size = ThumbnailLayout.baseSize

    var body: some View {
        content
            .frame(width: ThumbnailLayout.clamped(size), height: ThumbnailLayout.clamped(size))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch ThumbnailPresentation.content(for: imageUrl) {
        case .image(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    ThumbnailPlaceholder()
                }
            }
        case .placeholder:
            ThumbnailPlaceholder()
        }
    }
}

private struct ThumbnailPlaceholder: View {
    var body: some View {
        ZStack {
            Color.backgroundSecondaryColor
            Image(systemName: "gift")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
    }
}

#Preview("Placeholder and nil") {
    HStack(spacing: AppSpacing.md) {
        ItemThumbnail(imageUrl: nil)
        ItemThumbnail(imageUrl: "http://example.test/not-https.png")
    }
    .padding()
}

#Preview("Dark") {
    ItemThumbnail(imageUrl: nil)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Large type") {
    ItemThumbnail(imageUrl: nil)
        .padding()
        .dynamicTypeSize(.accessibility3)
}
