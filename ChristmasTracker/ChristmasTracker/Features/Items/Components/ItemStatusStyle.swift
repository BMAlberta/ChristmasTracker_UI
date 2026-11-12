//
//  ItemStatusStyle.swift
//  ChristmasTracker
//
//  The design-token color for each item status marker. Only views that were handed a marker by
//  the view state (never a raw item status) use it.
//

import SwiftUI

extension ItemStatus {
    var tokenColor: Color {
        switch self {
        case .available: Color.statusAvailableColor
        case .partial: Color.statusPartialColor
        case .purchased: Color.statusPurchasedColor
        case .wrapped: Color.statusWrappedColor
        case .gifted: Color.statusGiftedColor
        }
    }
}
