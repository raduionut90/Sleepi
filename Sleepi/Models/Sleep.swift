//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation

struct Sleep: Identifiable, Equatable {
    let id = UUID()
    let value: Int
    let startDate: Date
    let endDate: Date
    let source: String
    var heartRates: [HeartRate] = []
}
