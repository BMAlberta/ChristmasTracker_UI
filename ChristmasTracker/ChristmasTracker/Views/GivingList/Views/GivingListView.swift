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
                    Section {
                        NavigationLink(destination: ListDetailView(viewModel: ListDetailViewModel(_session, listInContext: i))) {
                            UserListOverviewView(data: i)
                        }
                    }
                }.listStyle(InsetGroupedListStyle())
                .navigationBarTitle("Available Lists")
            } else if (self.viewModel.isLoading) {
                ProgressView()
                    .navigationBarTitle("Available Lists")
            } else {
                Text("There are currently no lists available for you to view.")
                    .padding([.leading, .trailing], 48)
                    .navigationTitle("Available Lists")
            }
        }
        .navigationViewStyle(.stack)
        
        .onAppear {
            Task {
                if _session.sessionActive {
                    await self.viewModel.getOverview()
                }
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
    let data: ListOverviewDetails
    var body: some View {
        let members = FormatUtility.formatInitials(members: data.memberDetails)
        VStack(alignment: .leading) {
            HStack {
                VStack {
                    Text("Updated")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    StackedDateView(date: FormatUtility.convertStringToDate(rawDate: data.lastUpdateDate))
                }
                Divider()
                    .frame(width:1)
                    .overlay(.gray)
                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(data.listName)")
                        .font(.title2)
                    Text("\(data.ownerInfo.firstName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
//                    Divider()
//                        .frame(height:1)
//                        .overlay(.gray)
//                        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 8))
                    ProgressView("Progress", value: Double(data.purchasedItems), total: Double(data.totalItems))
                        .font(.caption)
                    Text("\(data.purchasedItems) out of \(data.totalItems) items purchased.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            HStack {
                AvatarListView(initials: members, maxAvatars: 4)
                    .alignmentGuide(.leading) { d in d[.leading] }
                Spacer()
                StateCapsule(state: .active)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
    }
    
    func memberView(for initials: String) -> some View {
            return AvatarView(initials: initials)
        }
    
    private func convertToPercentage() -> Double {
        let purchasedCount = data.purchasedItems
        let total = data.totalItems
        
        return Double(purchasedCount/total)
    }
}

struct UserListOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = ListOverviewDetails(listName: "Test name",
                                             totalItems: 10,
                                             purchasedItems: 2,
                                             id: "abcd",
                                             lastUpdateDate: "2022-11-12 12:30:12",
                                             ownerInfo: SlimUserModel(firstName: "Melanie",
                                                                     lastName: "Alberta",
                                                                      rawId: "1234"), memberDetails: [MemberDetail(firstName: "Brian", lastName: "Alberta", id: "1234")])
        UserListOverviewView(data: sampleData)
    }
}

struct AvatarView: View {
    let initials: String
    var body: some View {
        Text(initials)
            .fontWeight(.bold)
            .font(.system(size: 10))
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
          .foregroundColor(.white)
          .font(.callout)
          .background(.gray)
          .clipShape(Circle())
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarView(initials: "BA")
    }
}

struct AvatarListView: View {
    let initials: [String]
    var maxAvatars: Int
    
    var avatarList: [String] {
        return initials.prefix(maxAvatars).map{String($0)}
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(avatarList, id: \.self) { member in
                AvatarView(initials: member)
            }
            if (initials.count - maxAvatars > 0) {
                AvatarView(initials: "+\(initials.count - maxAvatars)")
            }
        }
    }
}

struct AvatarListView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarListView(initials: ["BA","MA","GA","NA"], maxAvatars: 2)
    }
}

struct StateCapsule: View {
    var state: State
    enum State {
        case active, inactive, expired
        
        var mappedColor: Color {
            switch self {
            case .active:
                return .green
            case .inactive:
                return .gray
            case .expired:
                return.red
            }
        }
        
        var mappedText: String {
            switch self {
            case .active:
                return "Active"
            case .inactive:
                return "Inactive"
            case .expired:
                return "Expired"
            }
        }
        
        var mappedTextColor: Color {
            switch self {
            case .active:
                return .white
            case .inactive:
                return .white
            case .expired:
                return .white
            }
        }
    }

    var body: some View {
        Text(state.mappedText)
            .font(.system(size: 10))
            .fontWeight(.bold)
            .font(.callout)
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundColor(state.mappedTextColor)
            .background(state.mappedColor)
            .clipShape(Capsule())
    }
}

struct StateCapsule_Previews: PreviewProvider {
    static var previews: some View {
        StateCapsule(state: .expired)
    }
}

struct StackedDateView: View {
    let date: Date
    let dateFormatter = DateFormatter()
    
    var month: String {
        dateFormatter.dateFormat = "LLL"
        return dateFormatter.string(from: date)
    }
    
    var day: String {
        dateFormatter.dateFormat = "dd"
        return dateFormatter.string(from: date)
    }
    
    var year: String {
        dateFormatter.dateFormat = "YYYY"
        return dateFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(month)")
                .font(.system(size: 14))
                .font(.title2)
            Text("\(day)")
                .font(.system(size: 14))
                .font(.title3)
            Text("\(year)")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .font(.title)
        }
    }
}

struct StackedDateView_Previews: PreviewProvider {
    static var previews: some View {
        StackedDateView(date: Date())
    }
}
