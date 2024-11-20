//
//  NewListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/18/22.
//

import SwiftUI
import Combine
import UIKit

struct NewItemView: View {
    @StateObject var viewModel: NewItemViewModel
    @Binding var showingModal:Bool
    var editModeActive = false
    
    var body: some View {
        NavigationView {
            List {
                NameView(model: $viewModel.newItem)
                DescriptionView(model: $viewModel.newItem)
                
                LinkView(model: $viewModel.newItem)
                HStack {
                    PriceView(model: $viewModel.newItem)
                    QuantityView(model: $viewModel.newItem)
                }
                SaveButton(viewModel: viewModel, showingModal: $showingModal, editMode: editModeActive)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitle(editModeActive ? "Edit Item" : "Create New Item")
            .navigationBarItems(trailing: CloseButton(showingModal: $showingModal))
        }
    }
}

struct NewItemView_Previews: PreviewProvider {
    static var previews: some View {
        BindingNewItemViewPreview()
    }
}

struct BindingNewItemViewPreview : View {
    @State
    private var value = false
    
    var body: some View {
        NewItemView(viewModel: NewItemViewModel(UserSession(), listInContext: "abcd123456789"),
                    showingModal: $value)
    }
}


struct SaveButton: View {
    @State var viewModel: NewItemViewModel
    @Binding var showingModal: Bool
    @State var showError: Bool = false
    var editMode = false
    var body: some View {
        Button(action: {
            if editMode {
                Task {
                    await viewModel.updateItem()
                    showingModal.toggle()
                }
            } else if viewModel.allRequiredFieldsPresent() {
                Task {
                    await viewModel.saveItem()
                    showingModal.toggle()
                }
            } else {
                showError.toggle()
            }
            
        }) {
            Text("Save Item")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color("brandBackgroundPrimary"))
                .cornerRadius(15.0)
        }
        .padding(.top, 50)
        .alert(isPresented: $showError) {
            Alert(title: Text("Unable to Add Item"), message: Text("Please ensure that all fields are filled out before saving the item."), dismissButton: .default(Text("Ok"), action: {
                showError.toggle()
            }))
        }
    }
}

struct QuantityView: View {
    @Binding var model: NewItemModel
    @State private var isError = false
    var body: some View {
        VStack {
            Text("Quantity")
            TextField("Item quantity", text: $model.quantity, onEditingChanged: { editing in
                    let nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
                    self.isError = !Set(model.quantity).isSubset(of: nums)
            })
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(isError ? Color("brandBackgroundSecondary") : Color("brandBackgroundPrimary"), lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                
            if isError {
                Text("Input can be numbers only")
                    .font(.footnote)
                    .foregroundColor(Color("brandBackgroundSecondary"))
            } else {
                Spacer()
            }
        }
    }
}

struct PriceView: View {
    @Binding var model: NewItemModel
    @State private var temp: String = "$"
    var body: some View {
        VStack {
            Text("Price $")
            TextField("Item price", text: model.price != "" ? $model.price : $temp)
                .onChange(of: temp) { oldState, newState in
                    if !newState.hasPrefix("$") {
                        temp = "$\(model.price)"
                    }
                    if newState.hasPrefix("$") {
                        let trimmed = temp.dropFirst()
                        model.price = String(trimmed)
                    }
                }
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("brandBackgroundPrimary"), lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            Spacer()
        }
    }
}

struct LinkView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Link")
            TextField("Item link", text: $model.link)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("brandBackgroundPrimary"), lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
        }
    }
}

struct DescriptionView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Description")
            TextField("Enter more information about your item here.", text: $model.description)
                .autocapitalization(.sentences)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("brandBackgroundPrimary"), lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
        }
    }
}

struct NameView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Name")
            TextField("Item name", text: $model.name)
                .autocapitalization(.sentences)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("brandBackgroundPrimary"), lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
        }
    }
}

struct CloseButton: View {
    @Binding var showingModal: Bool
    var body: some View {
        Button(action: {
            showingModal.toggle()
        }) { Image(systemName: "xmark") }
    }
}

fileprivate struct BorderStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .colorMultiply(.gray)
            .foregroundColor(.gray)
            .border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/, width: 1)
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var bottomPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .padding(.bottom, self.bottomPadding)
                .onReceive(Publishers.keyboardHeight) { keyboardHeight in
                    let keyboardTop = geometry.frame(in: .global).height - keyboardHeight
                    let focusedTextInputBottom = UIResponder.currentFirstResponder?.globalFrame?.maxY ?? 0
                    self.bottomPadding = max(0, focusedTextInputBottom - keyboardTop - geometry.safeAreaInsets.bottom)
                }
                .animation(.easeOut, value: 0.16)
        }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
}

extension Publishers {
    // 1.
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue }
                .map { $0.cgRectValue.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        ).eraseToAnyPublisher()
    }
}

extension UIResponder {
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }
    
    private static weak var _currentFirstResponder: UIResponder?
    
    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
    
    var globalFrame: CGRect? {
        guard let view = self as? UIView else { return nil }
        return view.superview?.convert(view.frame, to: nil)
    }
}
