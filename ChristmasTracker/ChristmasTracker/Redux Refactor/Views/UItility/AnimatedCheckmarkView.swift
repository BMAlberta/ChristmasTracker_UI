//
//  AnimatedCheckmarkView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/21/25.
//

import SwiftUI

import SwiftUI

struct AnimatedCheckmarkView: View {
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
        .foregroundColor(borderInit ? .green : .black)
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
                path.move(to: CGPoint(x: 20, y: -40))
                path.addLine(to: CGPoint(x: 40, y: -20))
                path.addLine(to: CGPoint(x: 80, y: -60))
            }
            .trim(from: 0, to: displayCheckmark ? 1 : 0)
            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            .foregroundColor(displayCheckmark ? .green : .black)
            .offset(x: (geometry.size.width - 95) / 2, // Center horizontally
                                y: (geometry.size.height + 85) / 2)
            .animation(.spring(.bouncy, blendDuration: 2).delay(2), value: displayCheckmark)
            .onAppear() {
                displayCheckmark.toggle()
            }
        }
    
        
    }.background(.black.opacity(0.7))
  }
}

#Preview {
    AnimatedCheckmarkView()
}
