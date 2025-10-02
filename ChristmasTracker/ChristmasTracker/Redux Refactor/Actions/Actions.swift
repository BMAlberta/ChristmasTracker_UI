//
//  Actions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

protocol Action {
    var type: String { get }
}

// Base action types that everything inherits from
protocol AppAction: Action {}
protocol UserAction: Action {}
protocol ListAction: Action {}
protocol ItemAction: Action {}

