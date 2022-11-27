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
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: StatsViewModel
    
    var body: some View {
        NavigationView {
            if (viewModel.isLoading) {
                ProgressView()
                    .navigationTitle("Stats Dashboard")
            }
            else if viewModel.hasStats {
                Form{
                    Section ("Overview") {
                        Text("Total Spent $\(viewModel.totalAmountSpent, specifier: "%.2f")")
                            .font(.subheadline)
                    }
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
            else {
                Text("You currently do not have any purchase statistics available for viewing.")
                    .padding([.leading, .trailing], 48)
                    .navigationTitle("Stats Dashboard")
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                if _session.sessionActive {
                    await self.viewModel.getStats()
                }
            }
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await self.viewModel.getStats()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(viewModel: StatsViewModel(UserSession()))
    }
}
