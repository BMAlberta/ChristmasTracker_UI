//
//  Stats.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/18/21.
//

import SwiftUI
import Charts
import Combine

struct StatsView: View {
    @EnvironmentObject var _store: AppStore
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        NavigationView {
            if viewModel.hasStats {
                Form{
                    Section("Amount Spent per Person") {
                        GenericPieChartView(viewModel: viewModel.spentModel)
                            .frame(minWidth: 250, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                    }
                    Section("Distribution of Purchases") {
                        GenericBarChartView(viewModel: viewModel.purchasedModel)
                            .frame(minWidth: 250, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                    }
                }
                .navigationTitle("Stats Dashboard")
                .alert(isPresented: $viewModel.isErrorState) {
                    Alert(title: Text("Data Error"), message: Text("We're temporariliy unable to retrieve that data. Please try again."), dismissButton: .default(Text("Ok")))
                }
            }
            else if (viewModel.isLoading) {
                ProgressView()
                    .navigationTitle("Stats Dashboard")
            }
            else {
                Text("You currently do not have any purchase statistics available for viewing.")
                    .padding([.leading, .trailing], 48)
                    .navigationTitle("Stats Dashboard")
            }
        }.onAppear {
            self.viewModel.getStats()
        }
    }
}

struct StatsView_Previews: PreviewProvider {
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
        StatsView(viewModel: StatsViewModel(store))
            
    }
}
