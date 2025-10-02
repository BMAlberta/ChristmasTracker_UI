//
//  Middleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation
protocol Middleware<State> {
    associatedtype State
    
    func process(
        action: any Action,
        state: State,
        dispatch: @escaping (any Action) -> Void
    ) -> any Action
}
