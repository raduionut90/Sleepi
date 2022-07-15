//
//  SleepDetector.swift
//  Sleepi
//
//  Created by Ionut Radu on 05.07.2022.
//

import Foundation
import HealthKit

@MainActor
class SleepDetector: ObservableObject {
    private var healthStore: HealthStore?
    @Published var loading: Bool = true

    init(){
        print("init loading = \(loading)")
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func performSleepDetection() {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {

                    let endDate = Date()
                    
                    let startDate = await getStartDate(healthStore, endDate)
                    // for debugging
//                    let debugStartDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
//                    let debugHeartRates = await healthStore.startHeartRateQuery(startDate: debugStartDate, endDate: endDate)
//                    let debugActiveEnergy = await healthStore.activityQuery(startDate: debugStartDate, endDate: endDate)
//                    processRawData(debugHeartRates, debugActiveEnergy)
                    // stop debugging
                    
//                    print("startDate: \(startDate.formatted()) , endDate: \(endDate.formatted())")

                    let heartRates = await healthStore.startHeartRateQuery(startDate: startDate, endDate: endDate)
                    let activeEnergy = await healthStore.activeEnergyQuery(startDate: startDate, endDate: endDate)

                    let activities: [Activity] = Utils.getActivitiesFromRawData(heartRates, activeEnergy)
                    
                    performCalculation(activities: activities)
                    
                }
            }
        }
    }
    
    private func performCalculation(activities: [Activity]) {
        var lowActivities: [Activity] = []
        var highActivities: [Activity] = []
        let averageHr = Utils.getAverage(array: activities, by: .heartRate)
        
        print("AvrrHR: \(averageHr)")
        
        for (index, activity) in activities.enumerated() {
            let nextIndex = index + 1 >= activities.count ? activities.count - 1 : index + 1
                        
//            if activity.date.formatted() == "04.07.2022, 0:14" {
//                print("dw")
//            }
            
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
            if !isDataContinuity(activities[index].startDate, activities[nextIndex].startDate) {endingSleep(lowActivities: &lowActivities, highActivities: &highActivities)}

        }
    }
    
    private func getStartDate(_ healthStore: HealthStore, _ endDate: Date) async -> Date {
        
        var tmpStartDate = Calendar.current.startOfDay(for: endDate)
        tmpStartDate = Calendar.current.date(byAdding: .hour, value: -3, to: tmpStartDate)!

        var tmpEndDate = endDate

        var appSleeps: [HKSample] = []
        let result: Date = tmpStartDate

        while appSleeps.isEmpty || tmpStartDate < Calendar.current.date(byAdding: .day, value: -90, to: endDate)! {
            let sleeps = await healthStore.readRecordedSleepsBySleepi(startTime: tmpStartDate, endTime: tmpEndDate)
            
            for sleep in sleeps {
                let bundleIdentifier: String = Bundle.main.bundleIdentifier!
                if sleep.sourceRevision.source.bundleIdentifier.contains(bundleIdentifier){
                    appSleeps.append(sleep)
                }
            }
            
            tmpEndDate = tmpStartDate
            tmpStartDate = Calendar.current.date(byAdding: .day, value: -7, to: tmpStartDate)!
        }

        return appSleeps.last?.endDate ?? result
    }
    
    private func isDataContinuity(_ currentDate: Date, _ nextDate: Date) -> Bool {
        if nextDate.timeIntervalSinceReferenceDate - currentDate.timeIntervalSinceReferenceDate < 600 {
//            print("isDataContinuity")
            return true
        }
//        print("NoDataContinuity")

        return false
    }
    private func endingSleep(lowActivities: inout [Activity], highActivities: inout [Activity]) {
        let firstEntryTimeInterval = lowActivities.last?.startDate.timeIntervalSinceReferenceDate ?? 0
        let lastEntryTimeInterval = lowActivities.first?.startDate.timeIntervalSinceReferenceDate ?? 0
        //                    print("avgResultHr: \(avgResultHr) \(avgResultHr.isNaN ? false : avgResultHr > avgHr)")
        //                    print("avgResultActEng: \(avgResultActEng), start: \(highActivities.first?.date), end: \(highActivities.last?.date)")
        
        if (firstEntryTimeInterval - lastEntryTimeInterval) > 1200 {

            if let start = lowActivities.first?.startDate, let end = lowActivities.last?.startDate {
                print("\(start.formatted()) \(end.formatted())")
                healthStore?.saveSleepAnalysis(startTime: start, endTime: end)
                loading = false
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
        if (activity.actEng ?? 0) > 0.300  || (activity.hr ?? 0) > averageHr + 10  {
            return true
        }
        return false
    }
    

}
