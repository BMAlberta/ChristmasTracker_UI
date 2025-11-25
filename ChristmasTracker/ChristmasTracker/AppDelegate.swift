//
//  AppDelegate.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/3/25.
//

import Foundation
import UIKit
import NewRelic

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NewRelic.start(withApplicationToken:"AAa5a93068d03e7e5a5a139897dee85dd201133390-NRMA")
        return true
    }
}
