//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation

struct Sleep: Hashable, Identifiable, Equatable {
    static func == (lhs: Sleep, rhs: Sleep) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id = UUID()
    let startDate: Date
    let endDate: Date
    var stage: SleepStage?
    var epochs: [Epoch]?

    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    init(startDate: Date, endDate: Date, stage: SleepStage) {
        self.init(startDate: startDate, endDate: endDate)
        self.stage = stage
    }
    
    init(startDate: Date, endDate: Date, epochs: [Epoch]) {
        self.init(startDate: startDate, endDate: endDate)
        self.epochs = epochs
    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
    }
}
