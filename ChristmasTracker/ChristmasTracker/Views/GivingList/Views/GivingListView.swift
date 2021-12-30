//
//  GivingListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI
import Foundation

struct GivingListView: View {
    @StateObject var viewModel: GivingListViewModel
    @EnvironmentObject var _session: UserSession
    var body: some View {
        NavigationView {
            if viewModel.overviews.count > 0 {
                List(self.viewModel.overviews) { i in
                    NavigationLink(destination: ListDetailView(viewModel: ListDetailViewModel(_session, userInContext: i.user))) {
                        UserListOverviewView(data: i)
                    }
                }.navigationBarTitle("Available Lists")
            } else {
                ProgressView()
                    .navigationBarTitle("Available Lists")
            }
        }
        .navigationViewStyle(.stack)
        
        .onAppear {
            Task {
                await self.viewModel.getOverview()
            }
        }
        .refreshable {
            await self.viewModel.getOverview()
        }
    }
}

struct GivingListView_Previews: PreviewProvider {
    static var previews: some View {
        let session = UserSession()
        GivingListView(viewModel: GivingListViewModel(session))
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
