//
//  EnvironmentValues+ListService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

private struct ListServiceKey: EnvironmentKey {
    static let defaultValue: ListService = {
        let repository = MockListRepository()
        let dataStore = ListDataStore()
        return ListService(repository: repository, dataStore: dataStore)
    }()
}

extension EnvironmentValues {
    var listService: ListService {
        get { self[ListServiceKey.self] }
        set { self[ListServiceKey.self] = newValue }
    }
}
