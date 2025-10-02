//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

struct AppState: Equatable {
    var user: UserState
    var ui: UIState
    
    static let initialState = AppState(
        user: .initialState,
        ui: .initialState
    )
}


//struct AppState: Equatable {
//    var user: UserState
//    var cart: CartState
//    var products: ProductState
//    var ui: UIState
//    
//    static let initial = AppState(
//        user: UserState.initial,
//        cart: CartState.initial,
//        products: ProductState.initial,
//        ui: UIState.initial
//    )
//}
