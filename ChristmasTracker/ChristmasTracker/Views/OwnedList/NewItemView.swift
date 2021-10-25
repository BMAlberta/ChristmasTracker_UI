//
//  NewItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI
import Combine
import UIKit

struct NewItemView: View {
    @EnvironmentObject var _store: AppStore
    @State var model: NewItemModel = NewItemModel()
    @Binding var showingModal:Bool
    
    var body: some View {
        NavigationView {
            VStack {
                NameView(model: $model)
                DescriptionView(model: $model)
                
                LinkView(model: $model)
                HStack {
                    PriceView(model: $model)
                    QuantityView(model: $model)
                }
                SaveButton(model: $model, showingModal: $showingModal)
            }.padding()
            .background(Color(UIColor.systemBackground))
            .navigationBarTitle("Create New Item")
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
        NewItemView(showingModal: $value)
    }
}


struct SaveButton: View {
    @EnvironmentObject var _store: AppStore
    @Binding var model: NewItemModel
    @Binding var showingModal: Bool
    var body: some View {
        Button(action: {
            print("Save tapped")
            _store.dispatch(.list(action: .createItem(item: model)))
            showingModal.toggle()
        }) {
            Text("Save Item")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(width: 300, height: 50)
                .background(Color.green)
                .cornerRadius(15.0)
        }.padding(.top, 50)
    }
}

struct CategoryView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Category")
            TextField("Item category", text: $model.category)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
        }
    }
}

struct QuantityView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Quantity")
            TextField("Item quantity", text: $model.quantity)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
        }
    }
}

struct PriceView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Price")
            TextField("Item price", text: $model.price)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
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
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
        }
    }
}

struct DescriptionView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Description")
            TextField("Enter more information about your item here.", text: $model.description)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
        }
    }
}

struct NameView: View {
    @Binding var model: NewItemModel
    var body: some View {
        VStack {
            Text("Name")
            TextField("Item name", text: $model.name)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(10)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                .background(Color(UIColor.systemBackground))
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
//                .keyboardAdaptive()
        }
    }
}

struct CloseButton: View {
    @Binding var showingModal: Bool
    var body: some View {
        Button(action: {
            print("Closed")
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
