//
//  HorizontalPath.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.09.2022.
//

import SwiftUI

struct VerticalLine: Shape {
    let startPoint: CGPoint
    let x: Double
    let y: Double
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: startPoint)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        .stroke(.red, lineWidth: 2) as! Path
    }
}

struct HorizontalPath_Previews: PreviewProvider {
    static var previews: some View {
        VerticalLine(startPoint: CGPoint(x: 200, y: 200), x: 200, y: 400)
            .stroke(.red, lineWidth: 2)
    }
}
