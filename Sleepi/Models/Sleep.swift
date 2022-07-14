//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit

struct Sleep: Identifiable, Equatable, Hashable {
    let id = UUID()
    let rawSleep: HKCategorySample
    let heartRates: [HKQuantitySample]
    let activeEnergy: [HKQuantitySample]
    
    
//    func getSleepPoints() -> [SleepPoint] {
//        var result: [SleepPoint] = []
//        let activities: [Activity] = Utils.getActivitiesFromRawData(self.heartRates, self.activeEnergy)
//
//
//        return result
//    }
    
    func getDuration() -> Double {
        return rawSleep.endDate.timeIntervalSinceReferenceDate - rawSleep.startDate.timeIntervalSinceReferenceDate
    }
        
//    private func getOffsetX(startDate: Date,
//                           endDate: Date) -> SleepPoint {
//
//       let sleepPercent = ((endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate) / sleepDuration )
//       let offset = (sleepPercent) * screenWidth!
//
//    }
    
        
}
