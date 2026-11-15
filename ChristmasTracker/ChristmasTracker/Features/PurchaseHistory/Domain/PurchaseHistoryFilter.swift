//
//  PurchaseHistoryFilter.swift
//  ChristmasTracker
//
//  The filters of the purchase history. A nil field is "no filter": nil year is all years.
//

import Foundation

nonisolated struct PurchaseHistoryFilter: Equatable, Hashable, Sendable {
    var year: Int?
    var recipientId: String?
    var shippingStatus: PurchaseShippingStatus?

    init(year: Int? = nil, recipientId: String? = nil, shippingStatus: PurchaseShippingStatus? = nil) {
        self.year = year
        self.recipientId = recipientId
        self.shippingStatus = shippingStatus
    }

    /// True when only the year is set and it is the default year (nil is a default too).
    func isDefault(defaultYear: Int?) -> Bool {
        year == defaultYear && recipientId == nil && shippingStatus == nil
    }
}
