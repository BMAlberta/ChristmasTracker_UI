//
//  EducationView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/11/24.
//

import SwiftUI
struct EducationView: View {
    var model: EducationModel
    var body: some View {
        VStack {
            Text(model.educationTitle)
                .font(.title3)
            Text(model.educationDescription)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(10)
        }
        .onAppear {
            EducationUtility.recordEducationView(educationModel: self.model)
        }
    }
}

#Preview {
    EducationView(model: EducationModel(educationId: "1234",
                                        educationTitle: "What's this?",
                                        educationDescription: "You can now easily edit items that you have previously created. All fields are editable but, please note, that this item may have been purchased and the purchasers will not be made aware of any changes."))
}
