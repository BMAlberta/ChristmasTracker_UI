//
//  StatusDotLabel.swift
//  ChristmasTracker
//
//  TH1-T3: the compact status style, a small dot in the status color beside the status name in the
//  primary text color. No production screen needs it yet; it is built and previewed for the first
//  compact place. One accessibility element.
//

import SwiftUI

struct StatusDotLabel: View {
    private let style: StatusStyle

    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 8

    init(kind: StatusKind) {
        self.style = StatusStyle.style(for: kind)
    }

    init(status: ItemStatus) {
        self.init(kind: StatusKind(status))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Circle()
                .fill(Color(token: style.fill))
                .overlay {
                    if let edge = style.edge {
                        Circle().strokeBorder(Color(token: edge), lineWidth: StatusStyle.edgeWidth)
                    }
                }
                .frame(width: dotSize, height: dotSize)
            Text(style.shortLabel)
                .font(.appCaption1)
                .foregroundStyle(Color.textPrimaryColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.accessibilityLabel)
    }
}

#Preview("Dots, light") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(StatusKind.allCases, id: \.self) { kind in
            StatusDotLabel(kind: kind)
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
}

#Preview("Dots, dark") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(StatusKind.allCases, id: \.self) { kind in
            StatusDotLabel(kind: kind)
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
    .preferredColorScheme(.dark)
}
