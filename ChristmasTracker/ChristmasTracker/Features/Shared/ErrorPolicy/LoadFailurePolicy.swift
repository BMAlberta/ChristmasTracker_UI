//
//  LoadFailurePolicy.swift
//  ChristmasTracker
//
//  UX1a Story U1: the pure decision of what a screen shows when loads fail.
//

import Foundation

nonisolated struct LoadBanner: Sendable, Equatable {
    let message: String
    /// The sources Try Again repeats, deduplicated, in order of first appearance.
    let retryTargets: [LoadSource]
}

nonisolated enum LoadFailureOutcome: Sendable, Equatable {
    case none
    case staleData(LoadBanner)
    case merged(LoadBanner)
    /// At most two banners.
    case banners([LoadBanner])
    case fullError(LoadBanner)
    case leaveScreen
    case signInTakesOver
}

nonisolated enum LoadFailurePolicy {

    static let staleDataText = "Couldn't update. Showing saved data."

    /// Group priority; notFound and sessionEnded are handled before grouping.
    private static let priority: [LoadFailureCategory] = [
        .unreachable, .timeout, .server, .rateLimited, .forbidden, .other
    ]

    static func outcome(hasCachedData: Bool, failures: [LoadFailure]) -> LoadFailureOutcome {
        if failures.isEmpty { return .none }
        if failures.contains(where: { $0.category == .sessionEnded }) { return .signInTakesOver }
        if failures.contains(where: { $0.category == .notFound }) { return .leaveScreen }

        let groups = groupedByPriority(failures)
        if groups.count == 1, let only = groups.first {
            return singleGroupOutcome(only, hasCachedData: hasCachedData)
        }
        return .banners(twoBanners(groups, hasCachedData: hasCachedData))
    }

    // MARK: - Helpers

    private struct Group {
        let category: LoadFailureCategory
        let failures: [LoadFailure]

        var targets: [LoadSource] { LoadFailurePolicy.uniqueSources(failures.map(\.source)) }
    }

    private static func groupedByPriority(_ failures: [LoadFailure]) -> [Group] {
        priority.compactMap { category in
            let members = failures.filter { $0.category == category }
            return members.isEmpty ? nil : Group(category: category, failures: members)
        }
    }

    private static func uniqueSources(_ sources: [LoadSource]) -> [LoadSource] {
        var seen: Set<LoadSource> = []
        return sources.filter { seen.insert($0).inserted }
    }

    private static func banner(_ group: Group, hasCachedData: Bool, targets: [LoadSource]) -> LoadBanner {
        let useStale = hasCachedData && group.category.isConnectivity
        let message = useStale ? staleDataText : (group.failures.first?.plainMessage ?? staleDataText)
        return LoadBanner(message: message, retryTargets: targets)
    }

    private static func singleGroupOutcome(_ group: Group, hasCachedData: Bool) -> LoadFailureOutcome {
        let built = banner(group, hasCachedData: hasCachedData, targets: group.targets)
        guard hasCachedData else { return .fullError(built) }
        guard group.category.isConnectivity else { return .banners([built]) }
        return group.targets.count > 1 ? .merged(built) : .staleData(built)
    }

    private static func twoBanners(_ groups: [Group], hasCachedData: Bool) -> [LoadBanner] {
        let first = groups[0]
        let second = groups[1]
        let extraTargets = groups.dropFirst(2).flatMap(\.targets)
        let secondTargets = uniqueSources(second.targets + extraTargets)
        return [
            banner(first, hasCachedData: hasCachedData, targets: first.targets),
            banner(second, hasCachedData: hasCachedData, targets: secondTargets)
        ]
    }
}
