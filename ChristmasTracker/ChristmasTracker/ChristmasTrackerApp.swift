//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let store: Store<AppState>
    
    init() {
        // Use mock store for development/demo
#if MOCK
        self.store = StoreFactory.createMockStore()
#else
        self.store = StoreFactory.createProductionStore()
#endif
        
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
        }.onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if store.state.user.isLoggedIn {
                    store.dispatch(UserActions.checkForSession)
                }
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
        NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: "UserTappedOnScreenEvent")))
    }
}

extension UIApplication: @retroactive UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // set to `false` if you don't want to detect tap during other gestures
    }
}
