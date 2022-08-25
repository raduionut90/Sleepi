//
//  Epoch.swift
//  Sleepi
//
//  Created by Ionut Radu on 19.08.2022.
//

import Foundation

class Epoch: Equatable, Comparable {
    static func < (lhs: Epoch, rhs: Epoch) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: Epoch, rhs: Epoch) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let records: [Records]
    let startDate: Date
    var endDate: Date
    var meanHR: Double
    let meanActivity: Double
    var sleepClasification: SleepStage?
    
    init(activities: [Records]){
        self.records = activities
        self.meanHR = activities.compactMap( {$0.hr }).reduce(0, +) / Double(activities.compactMap( {$0.hr }).count)
        self.meanActivity = activities.compactMap( {$0.actEng }).reduce(0, +) / Double(activities.compactMap( {$0.actEng }).count)
        self.startDate = activities.first!.startDate
        self.endDate = activities.last!.endDate
    }
}
