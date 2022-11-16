//
//  Epoch.swift
//  Sleepi
//
//  Created by Ionut Radu on 19.08.2022.
//

import Foundation

class Epoch: Equatable, Comparable, Identifiable {
    static func < (lhs: Epoch, rhs: Epoch) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: Epoch, rhs: Epoch) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let records: [Record]
    var startDate: Date
    var endDate: Date
    var meanHR: Double
    let sumActivity: Double
    var stage: SleepStage?
    
    init(start: Date, end: Date, records: [Record], stage: SleepStage?){
        self.records = records
        self.meanHR = records.compactMap( {$0.hr }).reduce(0, +) / Double(records.compactMap( {$0.hr }).count)
        self.sumActivity = records.compactMap( {$0.actEng} ).reduce(0, +)
        self.startDate = start
        self.endDate = end
        self.stage = stage
    }
    
    func isChargingOrWalking() -> Bool {
        return self.records.contains(where: {$0.charging || $0.walking})
    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
    }
}
