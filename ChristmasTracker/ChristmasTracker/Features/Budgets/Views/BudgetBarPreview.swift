//
//  BudgetBarPreview.swift
//  ChristmasTracker
//
//  PAL1-P2: previews of the budget progress bar at each level, tinted the way BudgetCardView tints
//  it (`Color.budget(level:)`), so the near-limit bar fill can be checked in light, dark and large
//  type. Preview only: no production view uses it.
//

import SwiftUI

private struct BudgetBarPreviewSet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(BudgetLevel.allCases, id: \.self) { level in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(BudgetStateStyle.style(for: level).label)
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimaryColor)
                    ProgressView(value: level == .under ? 0.4 : (level == .nearLimit ? 0.92 : 1.0))
                        .tint(BudgetLevelColors.bar(for: level))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
    }
}

/// Mirrors the private helper of the same name in BudgetCardView: the bar takes the level's token.
private enum BudgetLevelColors {
    static func bar(for level: BudgetLevel) -> Color {
        Color.budget(level: level)
    }
}

#Preview("Budget bars, light") {
    BudgetBarPreviewSet()
}

#Preview("Budget bars, dark") {
    BudgetBarPreviewSet()
        .preferredColorScheme(.dark)
}

#Preview("Budget bars, large type") {
    BudgetBarPreviewSet()
        .dynamicTypeSize(.accessibility3)
}
