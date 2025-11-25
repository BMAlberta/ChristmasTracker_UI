//
//  UtilityViews.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/15/25.
//

import SwiftUI
import Combine

extension PurchaseState {
    var mappedColor: Color {
        switch self {
        case .available:
            return .green
        case .unavailable:
            return .gray
        case .purchased:
            return.red
        case .partial:
            return .yellow
        }
    }
    
    var mappedText: String {
        switch self {
        case .available:
            return "Available"
        case .purchased:
            return "Purchased"
        case .unavailable:
            return "Unavailable"
        case .partial:
            return "Partial"
        }
    }
    
    var mappedTextColor: Color {
        switch self {
        case .available:
            return .white
        case .purchased:
            return .white
        case .unavailable:
            return .white
        case .partial:
            return .white
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
struct PlaceholderStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .colorMultiply(.gray)
            .foregroundColor(.gray)
    }
}

extension Color {
    static var themeTextField: Color {
        return Color(red: 220.0/255.0, green: 230.0/255.0, blue: 230.0/255.0, opacity: 1.0)
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

struct AvatarView: View {
    let initials: String
    var body: some View {
        Text(initials)
            .fontWeight(.bold)
            .font(.system(size: 10))
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            .foregroundColor(.white)
            .font(.callout)
            .background(.gray)
            .clipShape(Circle())
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarView(initials: "BA")
    }
}

struct AvatarListView: View {
    let initials: [String]
    var maxAvatars: Int
    
    var avatarList: [String] {
        return initials.prefix(maxAvatars).map{String($0)}
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(avatarList, id: \.self) { member in
                AvatarView(initials: member)
            }
            if (initials.count - maxAvatars > 0) {
                AvatarView(initials: "+\(initials.count - maxAvatars)")
            }
        }
    }
}

struct StateCapsule: View {
    var state: ListStatus
    
    var body: some View {
        Text(state.mappedText)
            .font(.system(size: 10))
            .fontWeight(.bold)
            .font(.callout)
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundColor(state.mappedTextColor)
            .background(state.mappedColor)
            .clipShape(Capsule())
    }
}

struct StackedDateView: View {
    let date: Date
    let dateFormatter = DateFormatter()
    
    var month: String {
        dateFormatter.dateFormat = "LLL"
        return dateFormatter.string(from: date)
    }
    
    var day: String {
        dateFormatter.dateFormat = "dd"
        return dateFormatter.string(from: date)
    }
    
    var year: String {
        dateFormatter.dateFormat = "YYYY"
        return dateFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(month)")
                .font(.system(size: 14))
                .font(.title2)
            Text("\(day)")
                .font(.system(size: 14))
                .font(.title3)
            Text("\(year)")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .font(.title)
        }
    }
}

extension ListStatus {
    var mappedColor: Color {
        switch self {
        case .active:
            return .green
        case .archive:
            return .gray
        case .expired:
            return.red
        case .draft:
            return .gray
        }
    }
    
    var mappedText: String {
        switch self {
        case .active:
            return "Active"
        case .archive:
            return "Archived"
        case .expired:
            return "Expired"
        case .draft:
            return "Draft"
        }
    }
    
    var mappedTextColor: Color {
        switch self {
        case .active:
            return .white
        case .archive:
            return .white
        case .expired:
            return .white
        case .draft:
            return .white
        }
    }
}
