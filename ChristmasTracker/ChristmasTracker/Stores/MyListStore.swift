//
//  MyListStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import Combine

final class MyListStore: ObservableObject {
    @Published var items: [Item] = []
    private var _session: UserSession
        
    
    init(session: UserSession) {
        _session = session
    }
    
    func getItems() {
        
    }
    
    func createNewItem() {
        
    }
    
    func deleteItem() {
        
    }
}
