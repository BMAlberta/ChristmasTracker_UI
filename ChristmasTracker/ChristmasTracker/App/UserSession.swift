//
//  UserSession.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/14/21.
//

import Foundation
import Combine

protocol SessionManaging {
    var token: String { get }
    var sessionId: String? { get }
    var loggedInUser: User? { get }
    var sessionActive: Bool { get }
    
    func startSession()
    func startSession(token: String, activeUser: User?)
    func terminateSession()
}

class UserSession: ObservableObject, SessionManaging {
    var token: String = ""
    var sessionId: String? = nil
    var loggedInUser: User? = nil
    @Published var sessionActive = false
    private var sessionTimer: Timer? = nil
    
    func startSession() {
        
        self.sessionActive = true
    }
    
    func startSession(token: String, activeUser: User?) {
        self.token = token
        self.loggedInUser = activeUser
        self.sessionActive = true
    }
    
    func terminateSession() {
        self.sessionTimer?.invalidate()
        self.loggedInUser = nil
        self.sessionActive = false
        self.sessionId = nil
        self.token = ""
    }
    
    private func startSessionTimer() {
        self.sessionTimer = Timer()
    }
}


