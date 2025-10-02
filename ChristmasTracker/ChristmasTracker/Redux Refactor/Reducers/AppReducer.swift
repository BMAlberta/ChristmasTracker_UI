//
//  AppReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

func appReducer(state: AppState, action: any Action) -> AppState {
    var newState = state
    
    newState.user = userReducer(state: state.user, action: action)
//    newState.cart = cartReducer(
//        state: state.cart,
//        action: action,
//        userState: newState.user, // Use updated user state
//        products: state.products.items
//    )
//    newState.products = productReducer(state: state.products, action: action)
    newState.ui = uiReducer(state: state.ui, action: action)
    
    return newState
}
