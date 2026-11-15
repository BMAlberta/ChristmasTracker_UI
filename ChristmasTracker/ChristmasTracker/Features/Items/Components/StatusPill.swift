//
//  StatusPill.swift
//  ChristmasTracker
//
//  TH1-T3: a capsule filled with the status color and the status name in a label color chosen for
//  contrast. The words are always present; the pill reads as one accessibility element.
//

import SwiftUI

struct StatusPill: View {
    private let style: StatusStyle

    @Environment(\.colorScheme) private var colorScheme

    init(kind: StatusKind) {
        self.style = StatusStyle.style(for: kind)
    }

    init(status: ItemStatus) {
        self.init(kind: StatusKind(status))
    }

    var body: some View {
        Text(style.shortLabel)
            .font(.appCaption1.weight(.medium))
            .foregroundStyle(Color(label: style.label(for: colorScheme.themeMode)))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color(token: style.fill), in: .capsule)
            .overlay {
                if let edge = style.edge {
                    Capsule().strokeBorder(Color(token: edge), lineWidth: StatusStyle.edgeWidth)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.accessibilityLabel)
    }
}

#Preview("Pills, light") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(StatusKind.allCases, id: \.self) { kind in
            StatusPill(kind: kind)
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
}

#Preview("Pills, dark") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(StatusKind.allCases, id: \.self) { kind in
            StatusPill(kind: kind)
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
    .preferredColorScheme(.dark)
}

#Preview("Pills, large type") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(StatusKind.allCases, id: \.self) { kind in
            StatusPill(kind: kind)
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
    .dynamicTypeSize(.accessibility3)
}
