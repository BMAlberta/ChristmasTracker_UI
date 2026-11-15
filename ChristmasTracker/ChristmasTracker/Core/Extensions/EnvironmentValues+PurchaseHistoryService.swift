//
//  EnvironmentValues+PurchaseHistoryService.swift
//  ChristmasTracker
//
//  The environment default is built from the inert loader: a view that reads the service without
//  the app injecting one gets a failed load, never fake data.
//

import SwiftUI

private struct PurchaseHistoryServiceKey: EnvironmentKey {
    static let defaultValue: PurchaseHistoryService = PurchaseHistoryService(repository: InertPurchaseHistoryLoader())
}

extension EnvironmentValues {
    var purchaseHistoryService: PurchaseHistoryService {
        get { self[PurchaseHistoryServiceKey.self] }
        set { self[PurchaseHistoryServiceKey.self] = newValue }
    }
}
