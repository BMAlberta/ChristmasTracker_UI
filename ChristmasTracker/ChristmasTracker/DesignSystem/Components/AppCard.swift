//
//  AppCard.swift
//  ChristmasTracker
//
//  The one card surface: standard padding, the surface color, continuous rounded corners and a
//  hairline border. No shadow.
//

import SwiftUI

enum AppCardStyle {
    /// Corner radius of a card.
    static let cornerRadius: CGFloat = AppSpacing.md
    /// Width of the hairline border.
    static let borderWidth: CGFloat = 1
    /// Inner padding of a card.
    static let padding: CGFloat = AppSpacing.md
}

private struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppCardStyle.cornerRadius, style: .continuous)
        content
            .padding(AppCardStyle.padding)
            .background(Color.surfaceColor)
            .clipShape(shape)
            .overlay {
                shape.stroke(Color.borderColor, lineWidth: AppCardStyle.borderWidth)
            }
    }
}

extension View {
    /// Wraps the view in the standard card surface.
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

#Preview("Card") {
    Text("A card")
        .font(.appBody)
        .foregroundStyle(Color.textPrimaryColor)
        .appCard()
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
}

#Preview("Card, dark") {
    Text("A card")
        .font(.appBody)
        .foregroundStyle(Color.textPrimaryColor)
        .appCard()
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
        .preferredColorScheme(.dark)
}
