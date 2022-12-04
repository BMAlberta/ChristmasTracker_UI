//
//  UserSession.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/14/21.
//

import Foundation
import Combine

protocol SessionManaging {
    var loggedInUser: UserModel? { get }
    var sessionActive: Bool { get }
    var enrollmentInProgress: Bool { get set }
    var passwordResetInProgress: Bool { get set }
    
    func startSession(activeUser: UserModel?)
    func terminateSession()
}

class UserSession: ObservableObject, SessionManaging {
    var loggedInUser: UserModel? = nil
    @Published var sessionActive = false
    @Published var enrollmentInProgress = false
    @Published var passwordResetInProgress = false
    private var sessionTimer: Timer? = nil
    private var lastTouchTime: Date = Date()
    private var timeoutTime: TimeInterval = 600
    
    func startSession(activeUser: UserModel?) {
        self.loggedInUser = activeUser
        UserDefaults.standard.set(activeUser?.email, forKey: "savedId")
        self.sessionActive = true
        self.enrollmentInProgress = false
        self.passwordResetInProgress = false
        self.startSessionTimer()
    }
    
    func terminateSession() {
        self.sessionTimer?.invalidate()
        self.loggedInUser = nil
        self.sessionActive = false
        self.enrollmentInProgress = false
        self.passwordResetInProgress = false
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("UserTappedOnScreenEvent"), object: nil)
    }
    
    private func startSessionTimer() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateLastTouchTime), name: Notification.Name("UserTappedOnScreenEvent"), object: nil)
        
        let timer = Timer(timeInterval: 60.0, target: self, selector: #selector(checkSessionTimer), userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.current.add(timer, forMode: .common)
        self.sessionTimer = timer
    }
    
    @objc private func checkSessionTimer() {
        let timeSinceLastTouch = Date().timeIntervalSince(lastTouchTime)
        if timeSinceLastTouch > self.timeoutTime {
        Task {
                await AuthServiceStore.performLogout()
            }
            self.terminateSession()
        }
    }
    
    @objc private func updateLastTouchTime() {
        self.lastTouchTime = Date()
//        print("Notification received for touch event.")
    }
}


