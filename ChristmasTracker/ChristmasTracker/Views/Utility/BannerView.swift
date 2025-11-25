//
//  BannerView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/23/21.
//

import Foundation
import SwiftUI

struct Banner: View {

   struct BannerDataModel {
       var title:String
       var detail:String
       var type: BannerType
   }
   
   enum BannerType {
       case info
       case warning
       case success
       case error
       
       var tintColor: Color {
           switch self {
           case .info:
            return Color("brandBackgroundPrimary")
           case .success:
               return .green
           case .warning:
               return Color("brandWarning")
           case .error:
               return Color("brandBackgroundSecondary")
           }
       }
    
    var sfSymbol: String {
        switch self {
        case .info:
         return "info.circle"
        case .success:
            return "checkmark.seal"
        case .warning:
            return "exclamationmark.octagon"
        case .error:
            return "xmark.octagon"
        }
    }
   }
    let data: BannerDataModel
    @Binding var show: Bool
    var body: some View {
        VStack {
                HStack {
                    Image.init(systemName: data.type.sfSymbol)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title)
                            .bold()
                        Text(data.detail)
                            .font(Font.system(size: 15, weight: Font.Weight.light, design: Font.Design.default))
                    }
                    Spacer()
                }
                .foregroundColor(Color.white)
                .padding(12)
                .background(data.type.tintColor)
                .cornerRadius(8)
                Spacer()
            }
            .padding()
            .animation(.easeInOut, value: 2)
            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
            .onTapGesture {
                withAnimation {
                    self.show = false
                }
            }.onAppear(perform: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation {
                        self.show = false
                    }
                }
            })
    }
    
    private var announcementBanner: Banner {
            
            let daysLeft = Configuration.daysUntilChristmas()
            var bannerType: Banner.BannerType = .info
            var headerText = ""
            
            switch daysLeft {
            case 1..<6:
                bannerType = .error
                headerText = "Time is Almost Up!"
            case 6..<11:
                bannerType = .warning
                headerText = "Time is Running Out!"
            default:
                bannerType = .info
                headerText = "Keep an Eye on the Time!"
            }
            
            var detailText = "There are only \(daysLeft) days until Christmas!"
            if daysLeft == 1 {
                detailText = "There is only \(daysLeft) day until Christmas!"
            }
            
            let bannerModel = Banner.BannerDataModel(title: headerText,
                                                     detail: detailText,
                                                     type: bannerType)
            
            let banner = Banner(data: bannerModel,
                                show: .constant(true))
            return banner
        }
}


struct Overlay<T: View>: ViewModifier {
    
    @Binding var show: Bool
    let overlayView: T
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if show {
                overlayView
            }
        }
    }
}

extension View {
    func overlay<T: View>( overlayView: T, show: Binding<Bool>) -> some View {
        self.modifier(Overlay.init(show: show, overlayView: overlayView))
    }
}
