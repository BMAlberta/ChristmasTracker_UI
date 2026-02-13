//
//  SkeletonView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import SwiftUI
/// Skeleton loading placeholder with shimmer animation
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    @State private var isAnimating = false
    
    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 4 ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .task {
                guard !isAnimating else { return }
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.15),
                Color.gray.opacity(0.3)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}
/// Skeleton card matching ListPreviewCard layout
struct SkeletonListCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SkeletonListHeader()
            Divider()
            SkeletonListStatsRow()
            SkeletonProgressBar()
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct SkeletonListHeader: View {
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SkeletonTextBlock(width: 150, height: 20)
                SkeletonTextBlock(width: 100, height: 16)
            }
            Spacer()
            SkeletonView(width: 60, height: 24, cornerRadius: 4)
        }
    }
}

private struct SkeletonListStatsRow: View {
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            SkeletonStatBlock()
            SkeletonStatBlock()
            Spacer()
        }
    }
}

private struct SkeletonStatBlock: View {
    
    var body: some View {
        SkeletonView(width: 80, height: 40)
    }
}

private struct SkeletonProgressBar: View {
    
    var body: some View {
        SkeletonView(height: 4, cornerRadius: 2)
    }
}

private struct SkeletonTextBlock: View {
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        SkeletonView(width: width, height: height)
    }
}
#Preview("Skeleton View") {
    VStack(spacing: AppSpacing.md) {
        SkeletonView(width: 200, height: 20)
        SkeletonView(width: 150, height: 16)
        SkeletonView(height: 4)
    }
    .padding()
}
#Preview("Skeleton Card") {
    SkeletonListCard()
        .padding()
}
