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
    var origin: String?

    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
    }
    
    func isNap() -> Bool {
        let hour = Calendar.current.component(.hour, from: startDate)
        return (10 ... 19).contains(hour)
    }
}
