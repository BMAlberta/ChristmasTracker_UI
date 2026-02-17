//
//  EnvironemtValues+ItemService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

private struct ItemServiceKey: EnvironmentKey {
    static let defaultValue: ItemService = {
        let repository = MockItemRepository()
        let dataStore = ItemDataStore()
        return ItemService(repository: repository, dataStore: dataStore)
    }()
}

extension EnvironmentValues {
    var itemService: ItemService {
        get { self[ItemServiceKey.self] }
        set { self[ItemServiceKey.self] = newValue }
    }
}
