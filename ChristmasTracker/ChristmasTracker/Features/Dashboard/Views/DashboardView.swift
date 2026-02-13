//
//  DashboardView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI
struct DashboardView: View {
    // MARK: - Environment
    @Environment(\.authenticationService) private var authService
    // MARK: - State
    @State private var viewModel: DashboardViewModel
    // MARK: - Initialization
    init(apiClient: APIClient) {
        self._viewModel = State(initialValue: DashboardViewModel(apiClient: apiClient))
    }
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.lists.isEmpty {
                    // Initial loading
                    loadingView
                } else if let error = viewModel.error, viewModel.lists.isEmpty {
                    // Error state (only if no cached data)
                    ErrorStateView(error: error) {
                        Task {
                            await viewModel.loadLists()
                        }
                    }
                } else if viewModel.lists.isEmpty {
                    // Empty state
                    EmptyStateView(
                        icon: "gift.fill",
                        title: "No Lists Yet",
                        message: "Create your first gift list to get started",
                        actionTitle: "Create List",
                        action: {
                            // TODO: Phase 5 - Navigate to create list
                            print("Create list tapped")
                        }
                    )
                } else {
                    // Lists display
                    listsScrollView
                }
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refreshLists()
            }
            .task {
                // Load lists on appear
                if viewModel.lists.isEmpty {
                    await viewModel.loadLists()
                }
                // Background refresh if stale
                else if viewModel.shouldRefreshInBackground() {
                    await viewModel.refreshLists()
                }
            }
        }
    }
    // MARK: - Subviews
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonListCard()
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }
    private var listsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // Last updated indicator
                if let lastUpdated = viewModel.lastUpdated {
                    lastUpdatedView(date: lastUpdated)
                }
                // Lists
                ForEach(viewModel.lists) { list in
                    ListPreviewCard(list: list)
                        .onTapGesture {
                            // TODO: Phase 5 - Navigate to list detail
                            print("List tapped: \(list.name)")
                        }
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }
    private func lastUpdatedView(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.appCaption2)
                .foregroundColor(.textMutedColor)
            Text("Updated \(date.timeAgoDisplay)")
                .font(.appCaption2)
                .foregroundColor(.textMutedColor)
            Spacer()
        }
    }
}
// MARK: - Date Extension
extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
#Preview("With Lists") {
    DashboardView(apiClient: MockAPIClient.withMockData())
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
#Preview("Empty") {
    DashboardView(apiClient: MockAPIClient())
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
