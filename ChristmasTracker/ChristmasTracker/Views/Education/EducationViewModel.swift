//
//  EducationViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/11/24.
//

import SwiftUI
import Combine

struct EducationModel {
    let educationId: String
    let educationTitle: String
    let educationDescription: String
    
}

struct EducationUtility {
    
    static func recordEducationView(educationModel: EducationModel) {
        @AppStorage(educationModel.educationId) var modelDisplayed: Bool = false
        modelDisplayed = true
    }
    
    static func educationModelCanBeShown(educationModel: EducationModel) -> Bool {
        @AppStorage(educationModel.educationId) var modelDisplayed: Bool = false
        return !modelDisplayed
    }
}
