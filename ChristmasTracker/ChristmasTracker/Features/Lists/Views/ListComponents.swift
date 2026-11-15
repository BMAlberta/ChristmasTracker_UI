//
//  ListComponents.swift
//  ChristmasTracker
//
//  Small building blocks shared by the list screens and the dashboard. Design tokens only;
//  they take view-state values (never domain models or roles).
//

import SwiftUI

// MARK: - Badge

/// The role label of a list. The look comes from the tone the view state supplies.
struct ListBadge: View {
    let title: String
    let tone: ListRoleBadge.Tone

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let look = tone.look
        Text(title)
            .font(.appCaption1)
            .foregroundStyle(look.textColor(for: colorScheme.themeMode))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background {
                if let fill = look.fillColor {
                    RoundedRectangle(cornerRadius: AppSpacing.xs).fill(fill)
                }
            }
            .overlay {
                if let border = look.borderColor {
                    RoundedRectangle(cornerRadius: AppSpacing.xs)
                        .strokeBorder(border, lineWidth: RoleBadgeLook.borderWidth)
                }
            }
    }
}

#Preview("Role badges, light") {
    ListBadgePreviewColumn()
}

#Preview("Role badges, dark") {
    ListBadgePreviewColumn()
        .preferredColorScheme(.dark)
}

#Preview("Role badges, large type") {
    ListBadgePreviewColumn()
        .dynamicTypeSize(.accessibility3)
}

/// All four roles on the page color and on the card color, for the previews.
private struct ListBadgePreviewColumn: View {
    private static let roles: [(String, ListRoleBadge.Tone)] = [
        ("Owner", .owner), ("Co-Owner", .coOwner), ("Member", .member), ("Viewer", .viewer)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Self.roles, id: \.0) { role in
                    ListBadge(title: role.0, tone: role.1)
                }
            }
            .padding(AppSpacing.lg)
            .background(Color.backgroundPrimaryColor)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Self.roles, id: \.0) { role in
                    ListBadge(title: role.0, tone: role.1)
                }
            }
            .padding(AppSpacing.lg)
            .background(Color.surfaceColor)
        }
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
