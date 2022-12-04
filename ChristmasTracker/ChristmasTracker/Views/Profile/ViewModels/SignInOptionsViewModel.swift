//
//  SignInOptionsViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/2/22.
//

import Foundation
import Combine

class SignInOptionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var isSuccessState = false
    @Published var isBiometricEnabled = false
    @Published var updateInProgress = false
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
        self.isBiometricEnabled = BiometricUtility.biometricStatus == .enrolled
    }
    
    
    func handleBiometricToggle(targetValue: Bool, confirmedPassword: String) {
        guard !updateInProgress else {
            return
        }
        
        if targetValue {
            enableBiometricAuth(confimedPassword: confirmedPassword)
        } else {
            disableBiometricAuth()
        }
    }
    
    func enableBiometricAuth(confimedPassword: String) {
        self.updateInProgress = true
        self.isLoading = true
        guard let savedUsername = UserDefaults.standard.string(forKey: "savedId") else {
            self.updateInProgress = false
            return
        }
        
        let credentials = Credentials(username: savedUsername, password: confimedPassword)
        defer {
            self.isBiometricEnabled = BiometricUtility.biometricStatus == .enrolled
            self.updateInProgress = false
        }
        do {
            try BiometricUtility.handleBiometricEnrollment(credentials)
            self.isLoading = false
        } catch {
            //Build error config
            self.isErrorState = true
            self.isSuccessState = false
            self.isLoading = false
        }
    }
    
    func disableBiometricAuth() {
        self.isLoading = true
        self.updateInProgress = true
        defer {
            self.isBiometricEnabled = BiometricUtility.biometricStatus == .enrolled
            self.updateInProgress = false
        }
        do {
            try BiometricUtility.deleteStoredCredentials()
            self.isLoading = false
        } catch {
            //Build error config
            self.isErrorState = true
            self.isSuccessState = false
            self.isLoading = false
        }
        
        
    }
}
