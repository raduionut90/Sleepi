//
//  HeartRate.swift
//  Sleepi
//
//  Created by Ionut Radu on 17.05.2022.
//

import Foundation

struct HeartRate: Identifiable, Equatable {
    let id = UUID()
    let value: Double
    let startDate: Date
}
