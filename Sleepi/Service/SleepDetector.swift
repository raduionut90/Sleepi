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
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    fileprivate func getActivities(_ healthStore: HealthStore, _ startDate: Date, _ endDate: Date) async -> [Activity] {
        let heartRates = await healthStore.startHeartRateQuery(startDate: startDate, endDate: endDate)
        let activeEnergy = await healthStore.activeEnergyQuery(startDate: startDate, endDate: endDate)
        //                    let hrv = await healthStore.startHeartRateVariabilityQuery(startDate: startDate, endDate: endDate)
        //                    let rhr = await healthStore.startRestingHeartRateQuery(startDate: startDate, endDate: endDate)
        //                    let resp = await healthStore.startRespiratoryRateQuery(startDate: startDate, endDate: endDate)
        
        let activities: [Activity] = self.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy, hrvs: [], rhrs: [], respRates: [])
        return activities
    }
    
    func performSleepDetection() {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {

                    let endDate = Date()
                    
                    var startDate = await getStartDate(healthStore, endDate)
                    

                    // for debugging
//                    let debugStartDate = Calendar.current.date(byAdding: .day, value: -56, to: Date())!
//                    let debugEndDate = Calendar.current.date(byAdding: .day, value: +5, to: debugStartDate)!
//                    let debugsleeps = await healthStore.sleepQuery(date: debugStartDate)
//                    let debugsleeps2 = await healthStore.sleepQuery(date: Calendar.current.date(byAdding: .day, value: 1, to: debugStartDate)!)
//                    let debugsleeps3 = await healthStore.sleepQuery(date: Calendar.current.date(byAdding: .day, value: 2, to: debugStartDate)!)
//                    let debugsleeps4 = await healthStore.sleepQuery(date: Calendar.current.date(byAdding: .day, value: 3, to: debugStartDate)!)
//                    let debugsleeps5 = await healthStore.sleepQuery(date: Calendar.current.date(byAdding: .day, value: 4, to: debugStartDate)!)
//
//
//                    let debugHeartRates = await healthStore.startHeartRateQuery(startDate: debugStartDate, endDate: debugEndDate)
//                    let debugActiveEnergy = await healthStore.activeEnergyQuery(startDate: debugStartDate, endDate: debugEndDate)
//                    let debughrv = await healthStore.startHeartRateVariabilityQuery(startDate: debugStartDate, endDate: debugEndDate)
//                    let debugrhr = await healthStore.startRestingHeartRateQuery(startDate: debugStartDate, endDate: debugEndDate)
//                    let debugresp = await healthStore.startRespiratoryRateQuery(startDate: debugStartDate, endDate: debugEndDate)
//
//                    self.getActivitiesFromRawData(heartRates: debugHeartRates, activeEnergy: debugActiveEnergy, hrvs: debughrv, rhrs: debugrhr, respRates: debugresp)
//                     stop debugging
                    
                    
                    print("before while: startDate: \(startDate.formatted()) , endDate: \(endDate.formatted())")
                    while endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate > 84600 {
                        let next24h = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
                        let startOfNextDay = Calendar.current.startOfDay(for: next24h)
                        let nextDay12am = Calendar.current.date(byAdding: .hour, value: 12, to: startOfNextDay)!
                        
//                        print("sleepDetector: startDate: \(startDate.formatted()) , endDate: \(nextDay12am.formatted())")

                        let activities: [Activity] = await getActivities(healthStore, startDate, nextDay12am)
                        self.performCalculation(activities: activities)
                        startDate = nextDay12am
                    }

                    let activities: [Activity] = await getActivities(healthStore, startDate, endDate)
                    performCalculation(activities: activities)
                    self.loading = false
                }
            }
        }
    }
    
    private func performCalculation(activities: [Activity]) {
        var lowActivities: [Activity] = []
        var highActivities: [Activity] = []
        let averageHr = Utils.getAverage(array: activities, by: .heartRate)
        
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
            if !isDataContinuity(activities[index].startDate, activities[nextIndex].startDate) {
                endingSleep(lowActivities: &lowActivities, highActivities: &highActivities)
            }

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
        
        if (firstEntryTimeInterval - lastEntryTimeInterval) > 1200 {

            if let start = lowActivities.first?.startDate, let end = lowActivities.last?.startDate {
//                print("\(start.formatted()) \(end.formatted())")
                healthStore?.saveSleepAnalysis(startTime: start, endTime: end)
            }
//            print("")
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
    
    private func getActivitiesFromRawData(
            heartRates: [HKQuantitySample],
            activeEnergy: [HKQuantitySample],
            hrvs: [HKQuantitySample],
            rhrs: [HKQuantitySample],
            respRates: [HKQuantitySample]
    ) -> [Activity] {
        var activities: [Activity] = []

        for actEnergy in activeEnergy {
            let record = Activity(startDate: actEnergy.startDate, endDate: actEnergy.endDate, actEng: actEnergy.quantity.doubleValue(for: .kilocalorie()))
            activities.append(record)
        }
        
        for heartRate in heartRates {
            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
                                                Utils.dateTimeformatter.string(from: heartRate.startDate)} ) {
                existingRecord.hr = heartRate.quantity.doubleValue(for: HKUnit(from: "count/min"))
            } else {
                let record = Activity(startDate: heartRate.startDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
                activities.append(record)
            }
        }
        
//        for hrv in hrvs {
//            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
//                                                Utils.dateTimeformatter.string(from: hrv.startDate)} ) {
//                existingRecord.hrv = hrv.quantity.doubleValue(for: HKUnit(from: "ms"))
//            } else {
//                let record = Activity(startDate: hrv.startDate, hrv: hrv.quantity.doubleValue(for: HKUnit(from: "ms")))
//                activities.append(record)
//            }
//        }
//
//        for rhr in rhrs {
//            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
//                                                Utils.dateTimeformatter.string(from: rhr.startDate)} ) {
//                existingRecord.rhr = rhr.quantity.doubleValue(for: HKUnit(from: "count/min"))
//            } else {
//                let record = Activity(startDate: rhr.startDate, rhr: rhr.quantity.doubleValue(for: HKUnit(from: "count/min")))
//                activities.append(record)
//            }
//        }
//
//        for respRate in respRates {
//            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
//                                                Utils.dateTimeformatter.string(from: respRate.startDate)} ) {
//                existingRecord.respRate = respRate.quantity.doubleValue(for: HKUnit(from: "count/min"))
//            } else {
//                let record = Activity(startDate: respRate.startDate, respRate: respRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
//                activities.append(record)
//            }
//        }
        
        activities = activities.sorted { a,b in
            a.startDate < b.startDate
        }
        
//      used for debug
//        for record in activities {
//            print("\(record.startDate.formatted());"
//                  + "\(record.hr ?? 999);"
//                  + "\(record.actEng ?? 999);"
//                  + "\(record.hrv ?? 999);"
//                  + "\(record.rhr ?? 999);"
//                  + "\(record.respRate ?? 999)")
//        }
        
        return activities
    }
}
