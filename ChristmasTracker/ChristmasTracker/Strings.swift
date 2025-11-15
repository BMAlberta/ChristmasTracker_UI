//
//  Strings.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/14/25.
//

import Foundation

enum Strings {
    
    enum Login {
        case screenTitle
        
        var text: String {
            switch self {
            case .screenTitle:
                return "App.Title"
            }
        }
    }
}
