//
//  Step.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import Foundation
import HealthKit

struct Sleep: Hashable {
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
    
    func getStageSleepDuration(allSleepsHrAverage: Double, stage: SleepType) -> Double {
        var dateArr: [Date] = []
//        print(rawSleep.startDate.formatted())
        let heartRates = activities.filter({ $0.hr != nil })
        
        //start sleep -> first activity
//        dateArr.append(self.startDate)
//        dateArr.append(activities.first!.startDate)
        
        for (index, activity) in heartRates.enumerated() {
//            print("\(hr.startDate.formatted());\(hr.quantity.doubleValue(for: HKUnit(from: "count/min")))")
//            print("\(activity.startDate.formatted()), \(activity.endDate!.formatted()), \(activity.hr!), \(activity.stage!) ")
            
            switch stage {
            case .DeepSleep:
                if activity.hr! <= allSleepsHrAverage - 2 {
                    dateArr.append(activity.startDate)
                    dateArr.append(activity == heartRates.last ? self.endDate : heartRates[index + 1].startDate)
                }
            case .LightSleep:
                if activity.hr! <= allSleepsHrAverage + 8 &&
                    activity.hr! > allSleepsHrAverage - 2 {
                    dateArr.append(activity.startDate)
                    dateArr.append(activity == heartRates.last ? self.endDate : heartRates[index + 1].startDate)
                }
            case .RemSleep:
                if activity.hr! > allSleepsHrAverage + 8 {
                    dateArr.append(activity.startDate)
                    dateArr.append(activity == heartRates.last ? self.endDate : heartRates[index + 1].startDate)
                }
            case .Awake:
                ()
            }


        }
        var result = 0.0
        for (index, t) in dateArr.enumerated() {
            if index % 2 == 0 {
                result += dateArr[index + 1].timeIntervalSinceReferenceDate - t.timeIntervalSinceReferenceDate
            }
        }
        
//        for date in dateArr {
//            print(date.formatted())
//        }
        return result;
    }
    
}
