//
//  ActivityActionHandler.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/10/25.
//

import Foundation
protocol ActivityActionHandling {
    func process(_ action: ActivityActions, dispatch: @escaping (any Action) -> Void)
}

struct ActivityActionHandler: ActivityActionHandling {
    let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding) {
        self.apiService = apiService
    }
    
    func process(_ action: ActivityActions, dispatch: @escaping (any Action) -> Void) {
        switch action {

        case .loadActivity:
            fatalError("ActivityActionHandler: \(action) not implemented")
        case .activityLoaded:
            fatalError("ActivityActionHandler: \(action) not implemented")
        case .activityError(_):
            fatalError("ActivityActionHandler: \(action) not implemented")
        case .homeFeedLoaded(_):
            break
        }
    }
    
    
}
