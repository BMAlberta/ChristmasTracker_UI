//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    let sessionManager = UserSession()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .onAppear {
                    let appearance = UITabBarAppearance()
                    appearance.configureWithDefaultBackground()
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    UIApplication.shared.addTapGestureRecognizer()
                }
        }
    }
}

extension UIApplication {
    func addTapGestureRecognizer() {
        let keyWindow = connectedScenes.compactMap { $0 as? UIWindowScene  }.flatMap { $0.windows }.first { $0.isKeyWindow }
        guard let window = keyWindow else { return }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }

    @objc func tapAction(_ sender: UITapGestureRecognizer) {
//        print("User action taken")
        NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: "UserTappedOnScreenEvent")))
    }
}

extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // set to `false` if you don't want to detect tap during other gestures
    }
}
