//
//  Dashboard.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct Dashboard: View {
    @EnvironmentObject var _session: UserSession
    @State private var showOverlay = false
    
    var body: some View {
        if (_session.sessionActive) {
            TabView {
                GivingListView(viewModel: GivingListViewModel(_session))
                    .tabItem {
                        Image(systemName: "books.vertical")
                        Text("Giving")
                    }
                MyListsView(viewModel: MyListsViewModel(_session))
                    .tabItem {
                        Image(systemName: "list.dash")
                        Text("My List")
                    }
                StatsView(viewModel: StatsViewModel(_session))
                    .tabItem {
                        Image(systemName: "chart.xyaxis.line")
                        Text("Stats")
                    }
                ProfileView(viewModel: ProfileViewModel(_session))
                    .environmentObject(_session)
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("Profile")
                    }
            }
            .overlay(overlayView: announcementBanner,
                     show: $showOverlay)
            .onAppear(perform: {
                promptForOveralyIfNeeded()
            })
        } else {
            EmptyView()
        }
    }
    
    private var announcementBanner: Banner {
        
        let daysLeft = Configuration.daysUntilChristmas()
        var bannerType: Banner.BannerType = .info
        var headerText = ""
        
        switch daysLeft {
        case 1..<6:
            bannerType = .error
            headerText = "Time is Almost Up!"
        case 6..<11:
            bannerType = .warning
            headerText = "Time is Running Out!"
        default:
            bannerType = .info
            headerText = "Keep an Eye on the Time!"
        }
        
        var detailText = "There are only \(daysLeft) days until Christmas!"
        if daysLeft == 1 {
            detailText = "There is only \(daysLeft) day until Christmas!"
        }
        
        let bannerModel = Banner.BannerDataModel(title: headerText,
                                                 detail: detailText,
                                                 type: bannerType)
        
        let banner = Banner(data: bannerModel,
                            show: $showOverlay)
        return banner
    }
    
    
    private func promptForOveralyIfNeeded() {
        let daysLeft = Configuration.daysUntilChristmas()
        guard daysLeft > 0 && daysLeft < 31 else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showOverlay.toggle()
            }
        }
    }
}

struct Dashboard_Previews: PreviewProvider {
    static var previews: some View {
        
        Dashboard()
            .environmentObject(UserSession())
    }
}
