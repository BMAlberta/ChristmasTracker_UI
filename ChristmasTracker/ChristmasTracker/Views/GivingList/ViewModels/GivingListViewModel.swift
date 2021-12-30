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
    @Published var overviews: [ListOverview] = []
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
            let userOverviewResponse: UserListOverviewResponse = try await ListServiceStore.getListOverviewByUser(_session.token)
            let sortedOverviews = userOverviewResponse.listOverviews.sorted { $0.user.firstName < $1.user.firstName }
            self.overviews = sortedOverviews
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
}
