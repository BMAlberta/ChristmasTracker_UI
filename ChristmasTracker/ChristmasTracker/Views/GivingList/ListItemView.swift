//
//  ListItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/6/21.
//

import SwiftUI

struct ListItemView: View {
    let data: Item
    var hidePurchase = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(data.name)")
                .font(.title2)
            HStack(alignment: .center) {
                Text("\(data.description)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                Text("Last update: \(FormatUtility.convertDateStringToHumanReadable(rawDate: data.lastEditDate))")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                
                Spacer()
            }
            if !hidePurchase {
                HStack {
                    Spacer()
                    Text("Purchased?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Image(systemName: data.purchased ? "checkmark.circle.fill" : "x.circle.fill")
                        .foregroundColor(data.purchased ? .green : .red)
                    Spacer()
                }
            }
        }
    }
}

struct ListItemView_Previews: PreviewProvider {
    static var previews: some View {
        let item = Item(id: "1234",
                        createdBy: "Brian",
                        creationDate: "2021-10-04",
                        description: "This an item that has a really long description that hopefully will be truncated properly.",
                        lastEditDate: "2021-10-04",
                        link: "www.lowes.com",
                        name: "Drill",
                        price: 230.00,
                        purchased: false,
                        purchaseDate: nil,
                        quantity: 1,
                        v: 1)
        ListItemView(data: item, hidePurchase: false)
    }
}
