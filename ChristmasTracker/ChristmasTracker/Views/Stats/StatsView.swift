//
//  StatsView_Redux.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//
import SwiftUI
import Charts

struct BudgetDashboardView: View {
    @State private var selectedFilters: Set<String> = ["All Lists"]
    let filters = ["All Lists", "Family", "Friends"]
    @StateObject var viewModel: StatsViewModel
    
    var body: some View {
        
        //        Text("Content Under Construction...")
        //            .font(.brandFont(size: 16))
        ScrollView {
            if (viewModel.isErrorState || !viewModel.hasStats) {
                Spacer()
                Text("You currently do not have any purchase statistics available for viewing.")
                    .padding([.leading, .trailing], 48)
                Spacer()
            } else {
                VStack(spacing: 16) {
                    // Budget Card
                    TotalSpendCard(data: viewModel.totalAmountSpent)
                    //Filter Carousel
    //                ScrollView(.horizontal, showsIndicators: false) {
    //                    HStack(spacing: 12) {
    //                        ForEach(filters, id: \.self) { filter in
    //                            FilterButton(
    //                                title: filter,
    //                                isSelected: selectedFilters.contains(filter),
    //                                action: {
    //                                    if selectedFilters.contains(filter) {
    //                                        selectedFilters.remove(filter)
    //                                    } else {
    //                                        selectedFilters.insert(filter)
    //                                    }
    //                                }
    //                            )
    //                        }
    //                    }
    //                    .padding(.horizontal)
    //                }
                    
                    // Stats Cards
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Items Purchased",
                            icon: "bag.fill",
                            iconColor: .black,
                            value: "\(viewModel.numberOfPurchases)",
                            subtitle: "",
                            subtitleColor: .green
                        )
                        
                        StatCard(
                            title: "Avg. Per Item",
                            icon: "dollarsign.square.fill",
                            iconColor: Color(red: 1.0, green: 0.8, blue: 0.0),
                            value: String(format: "$ %.2f", viewModel.averageSpend),
                            subtitle: "across all lists",
                            subtitleColor: .gray
                        )
                    }
                    .padding(.horizontal)
                    
                   
                    // Spending by List
                    ForEach(viewModel.listSpendDetails, id: \.self.id) { statDetail in
                        SpendingListRow(name: statDetail.listName,
                                        color: Self.generateColor(keyIndex: self.findIndex(item: statDetail)),
                                        itemsCount: statDetail.totalItems,
                                        amount: String(format: "$%.2f", statDetail.totalSpend),
                                        percentage: "\(Int(statDetail.percentageSpend * 100))% of total spent",
                                        progress: statDetail.percentageSpend)
                    }
                    
                    // Recent Purchases
    //                VStack(alignment: .leading, spacing: 12) {
    //                    HStack {
    //                        Text("Recent Purchases")
    //                            .font(.title3)
    //                            .fontWeight(.semibold)
    //
    //                        Spacer()
    //
    //                        Button("View All") {
    //                            // Action
    //                        }
    //                        .foregroundColor(.red)
    //                        .fontWeight(.medium)
    //                    }
    //                    .padding(.horizontal)
    //
    //                    VStack(spacing: 0) {
    //                        PurchaseRow(
    //                            icon: "gift.fill",
    //                            iconColor: Color(red: 0.8, green: 0.2, blue: 0.3),
    //                            title: "Wireless Headphones",
    //                            subtitle: "Family List • Mom",
    //                            amount: "$149.99",
    //                            timeAgo: "2 days ago"
    //                        )
    //
    //                        Divider()
    //                            .padding(.leading, 72)
    //
    //                        PurchaseRow(
    //                            icon: "table.furniture.fill",
    //                            iconColor: Color(red: 0.3, green: 0.4, blue: 0.3),
    //                            title: "Coffee Table Book",
    //                            subtitle: "Friends List • Sarah",
    //                            amount: "$32.50",
    //                            timeAgo: "5 days ago"
    //                        )
    //
    //                        Divider()
    //                            .padding(.leading, 72)
    //
    //                        PurchaseRow(
    //                            icon: "puzzlepiece.extension.fill",
    //                            iconColor: Color(red: 1.0, green: 0.8, blue: 0.0),
    //                            title: "Board Game Set",
    //                            subtitle: "Family List • Kids",
    //                            amount: "$89.99",
    //                            timeAgo: "1 week ago"
    //                        )
    //                    }
    //                    .background(Color.white)
    //                    .cornerRadius(12)
    //                    .padding(.horizontal)
    //                }
                    
                    // Monthly Spending Trend
    //                VStack(alignment: .leading, spacing: 12) {
    //                    Text("Monthly Spending Trend")
    //                        .font(.title3)
    //                        .fontWeight(.semibold)
    //                        .padding(.horizontal)
    //
    //                    BarChart()
    //                        .frame(height: 250)
    //                        .padding(.horizontal)
    //                }
                }
                .padding(.vertical)
            }
        }
        .background(Color.background)
        .onAppear {
            Task {
                await self.viewModel.getStats()
            }
        }
    }
    
    private func findIndex(item: SpendingListDetails) -> Int {
        guard let index = self.viewModel.listSpendDetails.firstIndex(of: item) else { return 0 }
        return index
    }
    
    private static func generateColor(keyIndex: Int?) -> Color {
        let colors: [Color] = [.primaryRed, .primaryGreen, .brandWarning, .warningText]
        guard let keyIndex else { return .primaryRed }
        
        let index = keyIndex % colors.count
        return colors[index]
    }
}

struct TotalSpendCard: View {
    var data: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total Spent")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "wallet.pass.fill")
                    .foregroundColor(.white)
            }
            
            Text(String(format: "$%.2f", data))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
            
            //            Text("of $2,000.00 spent")
            //                .font(.subheadline)
            //                .foregroundColor(.white.opacity(0.9))
            //
            //            ProgressView(value: 0.624)
            //                .progressViewStyle(LinearProgressViewStyle(tint: .white))
            //                .background(Color.white.opacity(0.3))
            //                .cornerRadius(4)
            //
            //            Text("$752.50 remaining")
            //                .font(.subheadline)
            //                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.8, green: 0.2, blue: 0.3), Color(red: 0.7, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct BudgetCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total Budget")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "wallet.pass.fill")
                    .foregroundColor(.white)
            }
            
            Text("$1,247.50")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
            
            Text("of $2,000.00 spent")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            ProgressView(value: 0.624)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.3))
                .cornerRadius(4)
            
            Text("$752.50 remaining")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.8, green: 0.2, blue: 0.3), Color(red: 0.7, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(red: 0.8, green: 0.2, blue: 0.3) : Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

struct StatCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let value: String
    let subtitle: String
    let subtitleColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(subtitleColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct SpendingListRow: View {
    let name: String
    let color: Color
    let itemsCount: Int
    let amount: String
    let percentage: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    
                    Text(name)
                        .font(.headline)
                }
                
                Spacer()
                
                Text(amount)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("\(itemsCount) items purchased")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(percentage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .background(Color(.systemGray5))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PurchaseRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let amount: String
    let timeAgo: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(iconColor)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount)
                    .font(.body)
                    .fontWeight(.semibold)
                
                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

struct PieChart: View {
    let data: [(String, Double)] = [
        ("Brian", 225),
        ("Melanie", 500),
        ("Nikki", 345),
        ("Graham", 200),
        ("Dennis", 175),
        ("David", 200),
        ("Owen", 430),
        ("Gayle", 310),
        ("Bill", 150)
    ]
    
    var body: some View {
        Chart {
            ForEach(data, id: \.0) { list, value in
                SectorMark(
                    angle: .value(list, value),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .cornerRadius(10)
                .foregroundStyle(by: .value("List", list))
            }
        }
        .scaledToFit()
    }
}

struct BarChart: View {
    let data: [(String, Double)] = [
        ("Oct", 500),
        ("Nov", 850),
        ("Dec", 1300)
    ]
    
    var body: some View {
        Chart {
            ForEach(data, id: \.0) { month, value in
                BarMark(
                    x: .value("Month", month),
                    y: .value("Amount", value)
                )
                .foregroundStyle(Color(red: 0.8, green: 0.2, blue: 0.3))
                .cornerRadius(6)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(Int(amount))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let month = value.as(String.self) {
                        Text(month)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .chartYScale(domain: 0...1500)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct BudgetDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetDashboardView(viewModel: StatsViewModel())
    }
}
