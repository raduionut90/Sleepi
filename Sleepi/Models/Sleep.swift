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

    func getActivities() -> [Activity] {
        Utils.getActivitiesFromRawData(heartRates, activeEnergy)
    }
    
    func getHeartRateAverage() -> Double {
        Utils.getAverage(array: getActivities(), by: .heartRate)
    }
    
    func getDuration() -> Double {
        return rawSleep.endDate.timeIntervalSinceReferenceDate - rawSleep.startDate.timeIntervalSinceReferenceDate
    }
    
}
