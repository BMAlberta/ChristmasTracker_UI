//
//  Toast.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation


struct Toast: Codable {
    let heading: String
    let body: String
    let icon: String
    let action: ToastAction
}

enum ToastAction: Codable {
    case dismiss
}
