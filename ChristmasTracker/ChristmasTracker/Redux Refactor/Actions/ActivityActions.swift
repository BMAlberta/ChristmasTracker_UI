//
//  ActivityActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation
enum ActivityActions: Action {
    case loadActivity
    case activityLoaded
    case activityError(Error)
    
    
    var type: String {
        switch self {
        case .loadActivity: "LOAD_ACTIVITY"
        case .activityLoaded: "ACTIVITY_LOAD_SUCCESS"
        case .activityError: "ACTIVITY_LOAD_ERROR"
        }
    }
}
