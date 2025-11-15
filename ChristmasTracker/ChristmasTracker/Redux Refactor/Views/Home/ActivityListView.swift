//
//  ActivityListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/25/25.
//

import SwiftUI

struct ActivityListView: View {
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ActivityListViewState>

    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                ActivityListViewState(
                    isLoading: appState.activity.isLoading,
                    activityList: appState.activity.currentActivity
                )
            }
        ))
    }
    
    
    var body: some View {
        
        if (viewStore.state.activityList.isEmpty) {
            Text("No Activity to show")
        } else {
            VStack(alignment: .leading) {
                ForEach(viewStore.state.activityList) { activity in
                    ActivityItemView(activity: activity)
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    Divider()
                }
            }
        }
    }
}

struct ActivityItemView: View {
    var activity: ActivityItem
    var body: some View {
        HStack {
            Image(systemName: activity.type.imageName)
                .resizable()
                .scaledToFit()
                .frame(width:32)
                .foregroundStyle(activity.type.imageTint)
                
            VStack(alignment: .leading) {
                generateActivityText()
                    .font(.brandFont(size: 14))
                    .foregroundStyle(.primaryText)
                Text(generateActivityTimeText())
                    .font(.brandFont(size: 12))
                    .foregroundStyle(.secondaryText)
            }
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
            Spacer()
            
        }.padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    
    private func generateActivityText() -> some View {
        
        switch activity.type {
        case .purchase:
            return Text("**\(activity.userName)** purchased \(activity.itemName) from \(activity.listName)")
        case .retraction:
            return Text("**\(activity.userName)** retracted their purchase of \(activity.itemName) from \(activity.listName)")
        case .itemAddition:
            return Text("**\(activity.userName)** added \(activity.itemName) to \(activity.listName)")
        case .itemRemoval:
            return Text("**\(activity.userName)** removed \(activity.itemName) from \(activity.listName)")
        case .listAddition:
            return Text("**\(activity.userName)** created \(activity.listName)")
        case .listRemoval:
            return Text("**\(activity.userName)** deleted \(activity.listName)")
        }
    }
    
    private func generateActivityTimeText() -> String {
        switch activity.type {
        case .purchase:
            return "2 hours ago"
        case .retraction:
            return "2 hours ago"
        case .itemAddition:
            return "2 hours ago"
        case .itemRemoval:
            return "2 hours ago"
        case .listAddition:
            return "2 hours ago"
        case .listRemoval:
            return "2 hours ago"
        }
    }
}

struct ActivityListViewState: Equatable {
    let isLoading: Bool
    let activityList: [ActivityItem]
}

#Preview {
    ActivityListView(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    ActivityListView(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
