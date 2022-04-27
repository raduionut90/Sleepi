//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation

struct Sleep: Identifiable {
    let id = UUID()
    let value: String
    let startDate: Date
    let endDate: Date
}
