//
//  AsyncMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/3/25.
//

import Foundation

struct AsyncMiddleware<State>: Middleware {
    private let apiService: APIServiceProviding
    private let userHandler: UserActionHandling
    private let listHandler: ListActionHandling
    private let uiHandler: UIActionHandling
    private let activityHandler: ActivityActionHandling
    private let statsHandler: StatsActionHandling
    
    init(apiService: APIServiceProviding = APIService()) {
        self.apiService = apiService
        self.userHandler = UserActionHandler(apiService: apiService)
        self.listHandler = ListActionHandler(apiService: apiService)
        self.uiHandler = UIActionHandler(apiService: apiService)
        self.activityHandler = ActivityActionHandler(apiService: apiService)
        self.statsHandler = StatsActionHandler(apiService: apiService)
    }
    
    func process(action: any Action, state: State, dispatch: @escaping (any Action) -> Void) -> any Action {
        if let userAction = action as? UserActions {
            self.userHandler.process(userAction, dispatch: dispatch)
        }
        
        if let uiAction = action as? UIActions {
            self.uiHandler.process(uiAction, dispatch: dispatch)
        }
        
        if let listAction = action as? ListActions {
            self.listHandler.process(listAction, dispatch: dispatch)
        }
        
        if let activityAction = action as? ActivityActions {
            self.activityHandler.process(activityAction, dispatch: dispatch)
        }
        
        if let statsAction = action as? StatsActions {
            self.statsHandler.process(statsAction, dispatch: dispatch)
        }
        
        return action
    }
}
