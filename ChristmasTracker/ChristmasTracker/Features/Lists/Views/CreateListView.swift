//
//  CreateListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

//struct CreateListView: View {
//    @Environment(\.listService) private var listService
//    @Environment(\.dismiss) private var dismiss
//    
//    // MARK: - Form State
//    @State private var name: String = ""
//    @State private var theme: String = ""
//    @State private var year: Int = Calendar.current.component(.year, from: Date())
//    @State private var recipientName: String = ""
//    @State private var description: String = ""
//    @State private var visibility: ListVisibility = .private
//    
//    @State private var isCreating = false
//    @State private var showError = false
//    @State private var errorMessage = ""
//    
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("List Details") {
//                    TextField("List Name", text: $name)
//                        .autocorrectionDisabled()
//                    
//                    TextField("Theme (optional)", text: $theme)
//                        .autocorrectionDisabled()
//                    
//                    Stepper("Year: \(year)", value: $year, in: 2020...2030)
//                }
//                
//                Section("Recipient") {
//                    TextField("Recipient Name", text: $recipientName)
//                        .autocorrectionDisabled()
//                    
//                    Text("Who is this list for?")
//                        .font(.appCaption1)
//                        .foregroundColor(.textMutedColor)
//                }
//                
//                Section("Description") {
//                    TextField("Add notes or details (optional)", text: $description, axis: .vertical)
//                        .lineLimit(3...6)
//                }
//                
//                Section("Privacy") {
//                    Picker("Who can see this list?", selection: $visibility) {
//                        Text("Private").tag(ListVisibility.private)
//                        Text("Invite Only").tag(ListVisibility.inviteOnly)
//                        Text("Public").tag(ListVisibility.public)
//                    }
//                    
//                    visibilityDescription
//                }
//            }
//            .navigationTitle("New List")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .disabled(isCreating)
//                }
//                
//                ToolbarItem(placement: .confirmationAction) {
//                    Button {
//                        Task {
//                            await createList()
//                        }
//                    } label: {
//                        if isCreating {
//                            ProgressView()
//                        } else {
//                            Text("Create")
//                        }
//                    }
//                    .disabled(!isFormValid || isCreating)
//                }
//            }
//            .alert("Error", isPresented: $showError) {
//                Button("OK") {}
//            } message: {
//                Text(errorMessage)
//            }
//        }
//    }
//    
//    // MARK: - Subviews
//    
//    private var visibilityDescription: some View {
//        Group {
//            switch visibility {
//            case .private:
//                Text("Only you can see this list.")
//                    .font(.appCaption1)
//                    .foregroundColor(.textMutedColor)
//            case .inviteOnly:
//                Text("Only invited members can see this list")
//                    .font(.appCaption1)
//                    .foregroundColor(.textMutedColor)
//            case .public:
//                Text("Anyone with the link can see this list.")
//                    .font(.appCaption1)
//                    .foregroundColor(.textMutedColor)
//            }
//        }
//    }
//    
//    // MARK: - Validation
//    
//    private var isFormValid: Bool {
//        !name.isEmpty && !recipientName.isEmpty
//    }
//    
//    // MARK: - Actions
//    
//    private func createList() async {
//        isCreating = true
//        
//        let request = CreateListRequest(name: name.trimmingCharacters(in: .whitespaces),
//                                        theme: theme.isEmpty ? nil : theme.trimmingCharacters(in: .whitespaces),
//                                        year: year,
//                                        recipientId: "temp-\(UUID().uuidString)",
//                                        description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
//                                        visibility: visibility,
//                                        coOwnerId: nil)
//        
//        do {
//            try await listService.createList(request)
//            dismiss()
//        } catch {
//            errorMessage = error.localizedDescription
//            showError = true
//        }
//        
//        isCreating = false
//    }
//    
//}
//
//#Preview {
//    CreateListView()
//        .environment(\.listService, ListService(
//            repository: MockListRepository(),
//            dataStore: ListDataStore()
//        ))
//}

// MARK: - Refactor

struct CreateListView: View {
    
    @Environment(\.listService) private var listService
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var name: String = ""
    @State private var recipientName: String = ""
    @State private var theme: String = ""
    @State private var description: String = ""
    @State private var visibility: ListVisibility = .private
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // List Details Card
                    listDetailsCard
                    
                    listMetadataCard
                    
                    // Visibility Card
                    visibilityCard
                    
                    // Year Card
                    yearCard
                }
                .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await createList()
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Custom Themed Cards
    
    private var listDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("List Details")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
            
            VStack(spacing: AppSpacing.md) {
                // List Name
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("List Name")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    TextField("e.g., Christmas 2024", text: $name)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .padding(AppSpacing.md)
                        .background(Color.backgroundSecondaryColor)
                        .cornerRadius(8)
                }
                
                // Recipient Name
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Recipient Name")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    TextField("e.g., Tommy", text: $recipientName)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .padding(AppSpacing.md)
                        .background(Color.backgroundSecondaryColor)
                        .cornerRadius(8)
                }
                
                // Theme (Optional)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Theme (Optional)")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    TextField("e.g., Star Wars, Princess, etc.", text: $theme)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .padding(AppSpacing.md)
                        .background(Color.backgroundSecondaryColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var listMetadataCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("List Metadata")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
            
            VStack(spacing: AppSpacing.md) {
             
                // Theme (Optional)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("(Optional)")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    TextField("Add notes or details (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .padding(AppSpacing.md)
                        .background(Color.backgroundSecondaryColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Visibility")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
            
            Picker("Visibility", selection: $visibility) {
                ForEach([ListVisibility.private, .public, .inviteOnly], id: \.self) { vis in
                    HStack {
                        Image(systemName: vis.icon)
                        Text(vis.displayName)
                    }
                    .tag(vis)
                }
            }
            .pickerStyle(.segmented)
            
            Text(visibility == .private ? "Only you can see this list" : "Others can view and purchase items")
                .font(.appCaption1)
                .foregroundColor(.textMutedColor)
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var yearCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Year")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
            
            HStack {
                Button {
                    year -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.appTitle3)
                        .foregroundColor(.primaryColor)
                }
                .disabled(year <= 2020)
                
                Spacer()
                
                Text("\(year.yearDisplay)")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimaryColor)
                
                Spacer()
                
                Button {
                    year += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.appTitle3)
                        .foregroundColor(.primaryColor)
                }
                .disabled(year >= 2030)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helpers
    
    private var isFormValid: Bool {
        !name.isEmpty && !recipientName.isEmpty
    }
    
    private func createList() async {
        isCreating = true
        
        let request = CreateListRequest(name: name.trimmingCharacters(in: .whitespaces),
                                        theme: theme.isEmpty ? nil : theme.trimmingCharacters(in: .whitespaces),
                                        year: year,
                                        recipientId: "temp-\(UUID().uuidString)",
                                        description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                                        visibility: visibility,
                                        coOwnerId: nil)
        
        do {
            try await listService.createList(request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isCreating = false
    }
}

#Preview {
    CreateListView()
        .environment(\.listService, ListService(
            repository: MockListRepository(),
            dataStore: ListDataStore()
        ))
}
