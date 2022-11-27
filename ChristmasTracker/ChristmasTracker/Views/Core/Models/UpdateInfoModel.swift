//
//  UpdateInfoModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct UpdateInfoModelResponse: Decodable {
    let version: UpdateInfoModel
}

struct UpdateInfoModel: Decodable {
    let availableVersion: String
    let downloadUri: String
}
