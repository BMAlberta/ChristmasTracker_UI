//
//  GivingListViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/3/21.
//

import Foundation
import Combine
import UIKit

class GivingListViewModel: ObservableObject {
    @Published var overviews: [ListOverviewDetails] = []
    @Published var isLoading = false
    @Published var isErrorState = false
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("purchaseStatusChanged"), object: nil)
    }
    
    @objc private func refreshList() {
        Task {
            await getOverview()
        }
    }
    
    @MainActor
    func getOverview() async {
        self.isLoading = true
        do {
            let userOverviewResponse: ListOverviewResponse = try await ListServiceStore.getListOverviewByUser()
            let sortedOverviews = userOverviewResponse.listOverviews.sorted {
//                ($0.ownerInfo.firstName < $1.ownerInfo.firstName) &&
                (FormatUtility.convertStringToDate(rawDate: $0.lastUpdateDate) > FormatUtility.convertStringToDate(rawDate: $1.lastUpdateDate))
            }
            self.overviews = sortedOverviews
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
}