//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit

struct Sleep: Hashable, Identifiable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let activities: [Activity]
    let heartRateAverage: Double

    init(startDate: Date, endDate: Date, activities: [Activity]) {
        self.startDate = startDate
        self.endDate = endDate
        self.activities = activities
        self.heartRateAverage = Utils.getAverage(array: activities, by: .heartRate)
    }
    
//    func setHeartRateAverage() -> Double {
//        heartRateAverage = Utils.getAverage(array: activities, by: .heartRate)
//    }
    
    func getDuration() -> Double {
        return self.endDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate
    }
    
    func getStageSleepDuration(allSleepsHrAverage: Double, stage: SleepStage) -> Double {
        var result: [TimeInterval] = []
        
        if stage == .LightSleep {
            result.append(self.activities.first!.startDate.timeIntervalSinceReferenceDate - self.startDate.timeIntervalSinceReferenceDate)
        }
        
        for activity in activities {
            switch stage {
            case .DeepSleep:
                if activity.stage == .DeepSleep {
                    result.append(activity.endDate!.timeIntervalSinceReferenceDate - activity.startDate.timeIntervalSinceReferenceDate)
                }
            case .LightSleep:
                if activity.stage == .LightSleep {
                    result.append(activity.endDate!.timeIntervalSinceReferenceDate - activity.startDate.timeIntervalSinceReferenceDate)
                }
            case .RemSleep:
                if activity.stage == .RemSleep {
                    result.append(activity.endDate!.timeIntervalSinceReferenceDate - activity.startDate.timeIntervalSinceReferenceDate)
                }
            case .Awake:
                ()
            }
        }
        return result.reduce(0, +);
    }
}
