//
//  RootView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var _session: UserSession
    @EnvironmentObject var _store: Store<AppState>
    var body: some View {
        if (!_session.sessionActive) {
            let viewModel = LoginViewModel(_session)
            LoginView(viewModel: viewModel)
        } else {
            Dashboard()
                .environmentObject(_session)
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
