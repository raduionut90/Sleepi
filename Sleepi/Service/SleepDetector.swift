//
//  SleepDetector.swift
//  Sleepi
//
//  Created by Ionut Radu on 05.07.2022.
//

import Foundation
import HealthKit

class SleepDetector {
    private var healthStore: HealthStore?

    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func performSleepDetection(date: Date){
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    let startDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
                    
                    let heartRates = await healthStore.startHeartRateQuery(startDate: startDate, endDate: date)
                    let activeEnergy = await healthStore.activityQuery(startDate: startDate, endDate: date)

                    let activities: [Activity] = processRawData(heartRates, activeEnergy)
                    
                    performCalculation(activities: activities)
                }
            }
        }
    }
    
    private func processRawData(_ heartRates: [HeartRate], _ activeEnergy: [HKQuantitySample]) -> [Activity] {
        var activities: [Activity] = []

        for actEnergy in activeEnergy {
            let record = Activity(date: actEnergy.startDate, actEng: actEnergy.quantity.doubleValue(for: .kilocalorie()))
            activities.append(record)
        }
        
        for heartRate in heartRates {
            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.date) ==
                                                Utils.dateTimeformatter.string(from: heartRate.startDate)} ) {
                existingRecord.hr = heartRate.value
            } else {
                let record = Activity(date: heartRate.startDate, hr: heartRate.value)
                activities.append(record)
            }

        }
        activities = activities.sorted { a,b in
            a.date < b.date
        }
        
        for record in activities {
            print("\(record.date.formatted());\(record.hr ?? 999);\(record.actEng ?? 999)")
        }
        
        return activities
    }
    
    private func performCalculation(activities: [Activity]) {
        var lowActivities: [Activity] = []
        var highActivities: [Activity] = []
        let averageHr = getAverage(array: activities, by: .heartRate)
        
        print("AvrrHR: \(averageHr)")
        
        for (index, activity) in activities.enumerated() {
            let nextIndex = index + 1 >= activities.count ? activities.count - 1 : index + 1
            
            if activity.date.formatted() == "04.07.2022, 0:14" {
                print("dw")
            }
            if (activity.actEng ?? 999) < 0.150  || (activity.hr ?? 999) < averageHr {
                
                lowActivities.append(activity)
             
                if lowActivities.count > 3 && highActivities.count > 3 {
                    let percentageOfHighValue: Double = Double(highActivities.count) / Double(lowActivities.count) * 100
                    if percentageOfHighValue > 40 {
                        endingSleep(lowActivities: &lowActivities, highActivities: &highActivities)
                    }
                }
            } else {
                if !lowActivities.isEmpty {
                    let percentageOfHighValue: Double = Double(highActivities.count) / Double(lowActivities.count) * 100

                    if !checkNextActivitiesAreLow(activities: activities, fromIndex: index, averageHr: averageHr) ||
                                isVeryHigh(activity: activities[nextIndex], averageHr: averageHr) ||
                        (percentageOfHighValue > 40 && activities.count > 3) {
                        endingSleep(lowActivities: &lowActivities, highActivities: &highActivities)
                    } else {
                        highActivities.append(activity)
                    }
                }

            }
        }
    }

    private func endingSleep(lowActivities: inout [Activity], highActivities: inout [Activity]) {
        let firstEntryTimeInterval = lowActivities.last?.date.timeIntervalSinceReferenceDate ?? 0
        let lastEntryTimeInterval = lowActivities.first?.date.timeIntervalSinceReferenceDate ?? 0
        //                    print("avgResultHr: \(avgResultHr) \(avgResultHr.isNaN ? false : avgResultHr > avgHr)")
        //                    print("avgResultActEng: \(avgResultActEng), start: \(highActivities.first?.date), end: \(highActivities.last?.date)")
        
        if (firstEntryTimeInterval - lastEntryTimeInterval) > 1200 {
            if let start = lowActivities.first?.date.formatted() {
                print(start)
                //                            if start == "04.07.2022, 5:53"{
                //                                print("jer")
                //                            }
            }
            if let end = lowActivities.last?.date.formatted() {
                print(end)
            }
            print("")
        }
        lowActivities = []
        highActivities = []

    }
    
    private func checkNextActivitiesAreLow(activities: [Activity], fromIndex: Int, averageHr: Double) -> Bool {
        var counter = 0
        var tempArray: [Activity] = []
        let nextActivityRange = 5
        let lastActivityChecked = fromIndex + nextActivityRange
        let lastIndex = lastActivityChecked >= activities.count ? activities.count - 1 : lastActivityChecked
        for index in fromIndex...lastIndex {
            tempArray.append(activities[index])
        }
        for activity in tempArray {
            if (activity.actEng ?? 999) < 0.150  || (activity.hr ?? 999) < averageHr {
                counter += 1
            }
        }
        return counter >= 2 ? true : false
    }
    
    private func isVeryHigh(activity: Activity, averageHr: Double) -> Bool {
        if (activity.actEng ?? 0) > 0.450  || (activity.hr ?? 0) > averageHr + 15  {
            return true
        }
        return false
    }
    
    private func getAverage(array: [Activity], by: HKQuantityTypeIdentifier) -> Double {
        if by == .heartRate {
            let sumResultHr = array.compactMap(\.hr).reduce(0.0, +)
            return (sumResultHr / Double(array.compactMap(\.hr).count))
        } else if by == .activeEnergyBurned {
            let sumResultHr = array.compactMap(\.actEng).reduce(0.0, +)
            return (sumResultHr / Double(array.compactMap(\.actEng).count))
        }
        return 0.0;
    }
}
