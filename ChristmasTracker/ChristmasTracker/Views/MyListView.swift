//
//  MyListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct MyListView: View {
    @EnvironmentObject var _store: AppStore
    @State private var editMode = EditMode.inactive
    @State var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List(_store.state.ownedList.items) { i in
                    NavigationLink(destination: LazyView(EmptyView())) {
                        ListItemView(data: i)
                    }
                }.navigationBarItems(leading: EditButton())
                .environment(\.editMode, $editMode)
                .navigationBarItems(leading: EditButton(), trailing: addItemButton)
                .navigationBarTitle("My Dashboard")
                
                if (_store.state.ownedList.fetchInProgess) {
                    ProgressView()
                }
            }
        }.onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchData(token: token)))
        }
    }
    
    
    private var addButton: some View {
        switch editMode {
        case .inactive:
            return AnyView(Button(action: onAdd) { Image(systemName: "plus") })
        default:
            return AnyView(EmptyView())
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            self.showingDetail.toggle()
            onAdd()
        }) {
            Image(systemName: "plus")
        }.sheet(isPresented: $showingDetail) {
            NewItemView(showingModal: $showingDetail)
            EmptyView()
        }
    }
    
    func onAdd() {
        // To be implemented in the next section
        print("Add button pressed")
    }
}

struct ListItemView: View {
    let data: Item
    
    var body: some View {
        VStack(alignment: .leading){
            Text("\(data.name)")
                .font(.title2)
            HStack(alignment: .center) {
                Text("\(data.description)")
                    .font(.subheadline)
                    .lineLimit(nil)
                Spacer()
                Text("Quantity(\(data.quantity))")
                    .font(.caption2)
            }
            HStack{
                Text("\(data.link)")
                    .font(.caption)
                    .fontWeight(.regular)
                Spacer()
                Text("$\(data.price, specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.thin)
            }
            HStack {
                Spacer()
                Text("Last update: \(data.lastEditDate)")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                
                Spacer()
            }
        }
    }
}
