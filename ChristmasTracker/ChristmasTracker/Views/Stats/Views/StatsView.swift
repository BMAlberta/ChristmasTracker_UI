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
    @State private var selectedFilterValue: StatsViewModel.FilterValue = .all
    
    var body: some View {
        NavigationView {
            if (viewModel.isLoading) {
                ProgressView()
                    .navigationTitle("Stats Dashboard")
            }
            VStack(alignment: .center, spacing: 0, content: {
                Text("Filter By Year")
                    .font(.caption)
                    .foregroundColor(Color(uiColor: .systemGray))
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                
                Picker("", selection: $selectedFilterValue, content: {
                    ForEach(StatsViewModel.FilterValue.allCases) { filterValue in
                        Text(filterValue.displayText).tag(filterValue)
                    }
                }).onChange(of: selectedFilterValue, perform: { (value) in
                    self.viewModel.processStats(filterValue: value)
                })
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                
                if viewModel.hasStats && !viewModel.isLoading {
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
                    .alert(isPresented: $viewModel.isErrorState) {
                        Alert(title: Text("Data Error"), message: Text("We're temporariliy unable to retrieve that data. Please try again."), dismissButton: .default(Text("Ok")))
                    }
                }
                else {
                    Spacer()
                    Text("You currently do not have any purchase statistics available for viewing.")
                        .padding([.leading, .trailing], 48)
                    Spacer()
                }
            })
            .navigationTitle("Stats Dashboard")
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                if _session.sessionActive {
                    await self.viewModel.getStats(selectedFilterValue: self.selectedFilterValue)
                }
            }
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await self.viewModel.getStats(selectedFilterValue: self.selectedFilterValue)
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
