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
    let store: Store<AppState>
    
    init() {
        // Use mock store for development/demo
        self.store = StoreFactory.createMockStore()
    }
    
    var body: some Scene {
        WindowGroup {
//            RootView()
//                .environmentObject(sessionManager)
//                .environmentObject(store)
//                .onAppear {
//                    let appearance = UITabBarAppearance()
//                    appearance.configureWithDefaultBackground()
//                    UITabBar.appearance().standardAppearance = appearance
//                    UITabBar.appearance().scrollEdgeAppearance = appearance
//                    UIApplication.shared.addTapGestureRecognizer()
//                }
            ContentView(store: store)
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
        NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: "UserTappedOnScreenEvent")))
    }
}

extension UIApplication: @retroactive UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // set to `false` if you don't want to detect tap during other gestures
    }
}
