//
//  GivingListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI
import Foundation

struct GivingListView: View {
    @EnvironmentObject var _store: AppStore
    var body: some View {
        NavigationView {
            List(_store.state.ownedList.overviews) { i in
                NavigationLink(destination: ListDetailView(user: i.user)) {
                    UserListOverviewView(data: i)
                }
            }.navigationBarTitle("Available Lists")
        }
        .navigationViewStyle(.stack)
        
        .onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchListOverview(token: token)))
        }
    }
}

struct GivingListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = AppStore(initialState: .init(
            authState: AuthState(),
            listState: ListState()
        ),
        reducer: appReducer,
        middlewares: [
            authMiddleware(service: AuthService()),
            logMiddleware(),
            listMiddleware(service: ListService())
        ])
        GivingListView().environmentObject(store)
    }
}

struct UserListOverviewView: View {
    let data: ListOverview
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading) {
                Text("\(data.user.firstName)")
                    .font(.title2)
                ProgressView("Completion %", value: Double(data.purchasedItems), total: Double(data.totalItems))
                    .font(.caption)
                Text("\(data.purchasedItems) out of \(data.totalItems) items purchased.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    private func convertToPercentage() -> Double {
        let purchasedCount = data.purchasedItems
        let total = data.totalItems
        
        return Double(purchasedCount/total)
    }
}
