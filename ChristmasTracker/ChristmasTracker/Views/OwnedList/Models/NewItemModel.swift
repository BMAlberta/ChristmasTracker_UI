//
//  NewItemModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation
import Combine
import os

class NewItemModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var link: String = ""
    @Published var price: String = ""
    @Published var quantity: String = ""
    @Published var category: String = ""
    
    
    func saveItem() {
        os_log("Saving the item")
        os_log("Name: \(self.name)\nDescription: \(self.description)\nLink: \(self.link)\nPrice: \(self.price)\nQuantity: \(self.quantity)\nCategory: \(self.category)")
    }
}

struct NewItemResponse: Decodable {
    let newItem: Item
}
