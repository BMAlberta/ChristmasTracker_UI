//
//  RootView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var _store: AppStore
    var body: some View {
        
        if (!_store.state.auth.isLoggedIn) {
            LoginView()
                .onAppear {
                    _store.dispatch(.auth(action: .fetchUpdateInfo))
                }
        } else {
            Dashboard()
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
