//
//  EnvironmentValues+PurchaseService.swift
//  ChristmasTracker
//

import SwiftUI

private struct PurchaseServiceKey: EnvironmentKey {
    static let defaultValue: PurchaseService = {
        // Previews and tests without an injected service: a recorder on mock data. Every item the
        // mock does not know is notFound.
        let recorder = MockPurchaseRecorder(access: { _ in .unknown })
        return PurchaseService(repository: recorder)
    }()
}

extension EnvironmentValues {
    var purchaseService: PurchaseService {
        get { self[PurchaseServiceKey.self] }
        set { self[PurchaseServiceKey.self] = newValue }
    }
}
