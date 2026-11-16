//
//  RecordPurchaseServiceReader.swift
//  ChristmasTracker
//
//  Reads the purchase service from the environment and hands it to a content builder, so a screen
//  that builds its own RecordPurchaseModel (for example with a starting input) does not have to
//  touch the service itself.
//

import SwiftUI

struct RecordPurchaseEnvironmentReader<Content: View>: View {
    @Environment(\.purchaseService) private var service
    private let content: (PurchaseService) -> Content

    init(@ViewBuilder content: @escaping (PurchaseService) -> Content) {
        self.content = content
    }

    var body: some View {
        content(service)
    }
}
