//
//  AnimatedErrorView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/1/25.
//

import SwiftUI

struct AnimatedErrorView: View {
  @State var borderInit: Bool = false
  @State var spinArrow: Bool = false
  @State var dismissArrow: Bool = false
  @State var displayCheckmark: Bool = false
  
  var body: some View {
    ZStack {
      // Border
      Circle()
        .strokeBorder(style: StrokeStyle(lineWidth: borderInit ? 10 : 64))
        .frame(width: 128, height: 128)
        .foregroundColor(borderInit ? .primaryRed : .black)
//        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: opacity)
        .animation(.easeOut(duration: 3).speed(1.5), value: borderInit)
//        .animation(.easeOut(duration: 3).speed(1.5))
        .onAppear() {
          borderInit.toggle()
        }
      
      // Arrow Icon
      Image(systemName: "arrow.2.circlepath")
        .font(.largeTitle)
        .foregroundColor(.white)
        .rotationEffect(.degrees(spinArrow ? 360 : -360))
        .opacity(dismissArrow ? 0 : 1)
        .animation(.easeOut(duration: 2), value: spinArrow)
        .onAppear() {
          spinArrow.toggle()
          withAnimation(Animation.easeInOut(duration: 1).delay(1)) {
              self.dismissArrow.toggle()
          }
        }
      
      // Checkmark
        GeometryReader { geometry in
            Path { path in
                let width: CGFloat = 60
                let height: CGFloat = 60

                // First diagonal line (top-left to bottom-right)
                path.move(to: CGPoint(x: 0, y:0))
                path.addLine(to: CGPoint(x: width, y: height))

                // Second diagonal line (top-right to bottom-left)
                path.move(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: 0, y: height))
            }
            .trim(from: 0, to: displayCheckmark ? 1 : 0)
            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            .foregroundColor(displayCheckmark ? .primaryRed : .black)
            .offset(x: (geometry.size.width - 60) / 2, // Center horizontally
                                y: (geometry.size.height - 60) / 2)
            .animation(.spring(.bouncy, blendDuration: 2).delay(2), value: displayCheckmark)
            .onAppear() {
                displayCheckmark.toggle()
            }
        }
    
        
    }.background(.black.opacity(0.7))
  }
}

#Preview {
    AnimatedErrorView()
}
