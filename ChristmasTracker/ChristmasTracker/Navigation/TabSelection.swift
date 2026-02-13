//
//  TabSelection.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import Foundation

enum TabSelection: String, CaseIterable, Identifiable {
    case dashboard
    case stats
    case profile
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .stats: return "Stats"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .stats: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
    
}
