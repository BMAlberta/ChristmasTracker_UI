//
//  ListComponents.swift
//  ChristmasTracker
//
//  Small building blocks shared by the list screens and the dashboard. Design tokens only;
//  they take view-state values (never domain models or roles).
//

import SwiftUI

// MARK: - Card style

private struct ListCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(EdgeInsets.appCardPadding)
            .background(Color.surfaceColor)
            .clipShape(.rect(cornerRadius: AppSpacing.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.md)
                    .stroke(Color.borderColor)
            }
    }
}

extension View {
    /// Surface card used by the list screens.
    func listCard() -> some View {
        modifier(ListCardStyle())
    }
}

// MARK: - Badge

/// The role label of a list. The colour comes from the tone the view state supplies.
struct ListBadge: View {
    let title: String
    let tone: ListRoleBadge.Tone

    var body: some View {
        Text(title)
            .font(.appCaption1)
            .foregroundStyle(Color.surfaceColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(tone.color, in: .rect(cornerRadius: AppSpacing.xs))
    }
}

/// Marks an archived list. Shown only when the view state says so (`showsArchivedBadge`).
struct ListArchivedBadgeView: View {
    var body: some View {
        Text(ListArchivedBadge.title)
            .font(.appCaption1)
            .foregroundStyle(Color.textMutedColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.xs)
                    .stroke(Color.borderColor)
            }
    }
}

// MARK: - Counts

/// Item and purchased counts with optional progress. Only built when the state shows counts.
struct ListCountsView: View {
    let itemCountText: String
    let purchasedCountText: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.lg) {
                Label(itemCountText, systemImage: "list.bullet")
                Label(purchasedCountText, systemImage: "checkmark.circle")
            }
            .font(.appSubheadline)
            .foregroundStyle(Color.textPrimaryColor)

            if let progress {
                ProgressView(value: progress)
                    .tint(.primaryColor)
                    .accessibilityLabel("Progress")
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }
        }
    }
}

// MARK: - Visibility description

extension ListVisibility {
    /// One line explaining who can see a list with this visibility.
    var summary: String {
        switch self {
        case .private: return "Only you can see this list."
        case .inviteOnly: return "Only people you invite can see this list."
        case .friendsOnly: return "Your friends can see this list."
        case .public: return "Anyone with the link can see this list."
        }
    }
}
