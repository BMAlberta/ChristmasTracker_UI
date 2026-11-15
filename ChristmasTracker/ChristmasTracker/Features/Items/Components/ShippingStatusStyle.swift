//
//  ShippingStatusStyle.swift
//  ChristmasTracker
//
//  PH1-H3: the pure look of the four shipping statuses for the compact dot: the fill token, the short
//  label and the accessibility label. Shipped uses the theme's shipped token. The other three use
//  neutral theme tokens (a status in progress is quiet, not colorful): Not tracked is the border
//  token, Not shipped the muted text token, Delivered the primary token. A weak fill gets the same
//  edge as `StatusStyle` through `ThemeEdgeRule`.
//

import Foundation

nonisolated struct ShippingStatusStyle: Equatable, Sendable {
    let status: PurchaseShippingStatus
    let fill: ThemeToken
    let shortLabel: String
    let accessibilityLabel: String

    /// The fills that get an edge, computed once from the token table by `ThemeEdgeRule`.
    private static let fillsWithEdge: Set<ThemeToken> = ThemeEdgeRule.fillsNeedingEdge()

    var needsEdge: Bool { Self.fillsWithEdge.contains(fill) }

    /// The edge token when the fill needs one, otherwise nil.
    var edge: ThemeToken? { needsEdge ? StatusStyle.edgeToken : nil }

    static func style(for status: PurchaseShippingStatus) -> ShippingStatusStyle {
        let fill: ThemeToken
        switch status {
        case .notTracked: fill = .border
        case .notShipped: fill = .textMuted
        case .shipped: fill = .statusShipped
        case .delivered: fill = .primary
        }
        return ShippingStatusStyle(
            status: status,
            fill: fill,
            shortLabel: status.displayName,
            accessibilityLabel: "Shipping: \(status.displayName)"
        )
    }
}
