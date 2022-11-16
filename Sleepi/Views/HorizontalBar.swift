//
//  VerticalPath.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.09.2022.
//

import SwiftUI

struct HorizontalBar: Shape {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRoundedRect(
                in: CGRect(x: x, y: y, width: width, height: height),
                cornerSize: .init(width: 10, height: 10),
                style: .continuous)
        }
    }
}
