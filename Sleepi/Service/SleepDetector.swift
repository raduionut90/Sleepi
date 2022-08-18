//
//  SleepDetector.swift
//  Sleepi
//
//  Created by Ionut Radu on 05.07.2022.
//

import Foundation
import HealthKit
import os

@MainActor
class SleepDetector: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SleepDetector.self)
    )
    private var healthStore: HealthStore?
    @Published var loading: Bool = true

    init(){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func performSleepDetection() {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {

                    let currentDate = Date()
                    
                    var startDate = await getStartDate(currentDate)
                    

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
                    
                    
//                    print("before while: startDate: \(startDate.formatted()) , endDate: \(endDate.formatted())")
                    let aWeekBefore = Calendar.current.date(byAdding: .day, value: -7, to: startDate)!
                    let sleeps = await healthStore.getSleeps(startTime: aWeekBefore, endTime: currentDate)
                    let lastSleepEndDate = sleeps.last?.endDate ?? aWeekBefore

                    if currentDate.timeIntervalSinceReferenceDate - lastSleepEndDate.timeIntervalSinceReferenceDate > 86400 {
                        startDate = lastSleepEndDate
                    }

                    let heartRates = await healthStore.getSamples(startDate: startDate, endDate: currentDate, type: .heartRate)
                    let meanHR = heartRates.map( { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ).reduce(0, +) / Double(heartRates.count)
                    let activeEnergy = await healthStore.getSamples(startDate: startDate, endDate: currentDate, type: .activeEnergyBurned)
                    //                    let hrv = await healthStore.startHeartRateVariabilityQuery(startDate: startDate, endDate: endDate)
                    //                    let rhr = await healthStore.startRestingHeartRateQuery(startDate: startDate, endDate: endDate)
                    //                    let resp = await healthStore.startRespiratoryRateQuery(startDate: startDate, endDate: endDate)
                    
                    let activities: [Activity] = self.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy, hrvs: [], rhrs: [], respRates: [])
                    let sortedActivEnergy = activities.map({ $0.actEng ?? 0 } ).filter({ $0 > 0.0 }).sorted(by: <)
                    let quariles = getQuartiles(values: sortedActivEnergy)

                    print(quariles)
                    
                    let firstQuartile = quariles[Constants.FIRST_QUARTILE]!
                    let thirdQuartile = quariles[Constants.THIRD_QUARTILE]!
                    
                    var detectedPairs = sleepDetection(activities: activities, firstQuartile: firstQuartile, thirdQuartile: thirdQuartile)
                    if sleeps.count > 0 {
                        //filter by last sleep date
                        detectedPairs = detectedPairs.filter( { $0.key.startDate > (sleeps.last?.endDate)! } )
                    }
                    let filteredSleep = removeShortSleepPairs(pairs: detectedPairs)
                    let potentialSleeps = evaluateActivitiesForPairs(pairs: filteredSleep, activities: activities, firstQuartile: firstQuartile)

                    let finalSleeps = evaluateHR(sleeps: potentialSleeps, meanHR: meanHR)
                    
                    for sleep in finalSleeps {
//                        print(sleep)
                        healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                    }

                    self.loading = false
                }
            }
        }
    }
    
    private func evaluateHR(sleeps: [Sleep], meanHR: Double) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let hr = sleep.activities.compactMap( { $0.hr } )
            let sleepMeanHr:Double = hr.reduce(0, +) / Double(hr.count)
            if meanHR > sleepMeanHr {
                result.append(sleep)
            }
        }
        return result
    }
    
    private func evaluateActivitiesForPairs(pairs: [Activity: Activity], activities: [Activity], firstQuartile: Double) -> [Sleep] {
        var sleeps: [Sleep] = []
        for pair in pairs {
            let startIndex = activities.firstIndex(where: {$0 == pair.key })!
            let endIndex = activities.firstIndex(where: {$0 == pair.value })!
            let totalActivitiesPerInterval = Array(activities[startIndex...endIndex])
            let lowActivity = totalActivitiesPerInterval.filter({ $0.actEng ?? 0 < firstQuartile })
            let percent = lowActivity.count * 100 / totalActivitiesPerInterval.count
            if percent > 70 {
                let sleep = Sleep(startDate: pair.key.startDate, endDate: pair.value.startDate, activities: totalActivitiesPerInterval)
                sleeps.append(sleep)
            }
            
            print("\(pair.key.startDate.formatted());\(pair.value.startDate.formatted());\(percent) ")
        }
        
        return sleeps
    }
    
    
    private func removeShortSleepPairs(pairs: [Activity: Activity]) -> [Activity: Activity] {
        // filter key value interval > 30 min
        return pairs.filter( { $0.value.startDate.timeIntervalSinceReferenceDate - $0.key.startDate.timeIntervalSinceReferenceDate > 1800} )
    }
    
    private func sleepDetection(activities: [Activity], firstQuartile: Double, thirdQuartile: Double) -> [Activity: Activity] {
        var acts = activities
        var indexSleepPairs: [Activity: Activity] = [:]
        
        while acts.first(where: { $0.actEng ?? 0 <  firstQuartile }) != nil {
            if let startAct = acts.first(where: { $0.actEng ?? 0 <  firstQuartile }){
                let startActIndex = acts.firstIndex(where: { $0.actEng ?? 0 <  firstQuartile })!
                acts = Array(acts[(startActIndex + 1)...])
                let endAct = acts.first(where: { $0.actEng ?? 99 >  thirdQuartile } ) ?? acts.last!
                let endActIndex = acts.firstIndex(where: { $0.actEng ?? 99 >  thirdQuartile } ) ?? acts.count - 1
                indexSleepPairs[startAct] = endAct
                acts = Array(acts[(endActIndex + 1)...])
            }

        }
        
        return indexSleepPairs
    }
    
    private func getQuartiles(values: [Double]) -> [Int: Double] {
        var result: [Int: Double] = [Constants.FIRST_QUARTILE: 0, Constants.MEDIAN: 0, Constants.THIRD_QUARTILE: 0];
        for quartileType in result {
            let length = values.count
            let quartileSize: Double = Double(length) * (Double(quartileType.key) * 25.0 / 100.0)
            if quartileSize.truncatingRemainder(dividingBy: 1) == 0 {
                result.updateValue(values[Int(quartileSize)], forKey: quartileType.key)
            } else {
                result.updateValue(((values[Int(quartileSize)] + values[Int(quartileSize) + 1]) / 2), forKey: quartileType.key)
            }
        }
        return result;
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
    
    private func getStartDate(_ currentDate: Date) async -> Date {
        
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .hour, value: -12, to: result)!

        return result
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
                healthStore?.saveSleep(startTime: start, endTime: end)
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
    
    fileprivate func processActivities(_ activities: inout [Activity]) {
        //      used for debug
        //        for record in activities {
        //            print("\(record.startDate.formatted());"
        //                  + "\(record.hr ?? 999);"
        //                  + "\(record.actEng ?? 999);"
        //                  + "\(record.hrv ?? 999);"
        //                  + "\(record.rhr ?? 999);"
        //                  + "\(record.respRate ?? 999)"
        //            )
        //            Self.logger.debug("\(record.startDate.formatted()) \(record.hr ?? 0) \(record.actEng ?? 0)")
        //        }
        
        for (index, record) in activities.enumerated() {
            var prev1: Double = 0.0
            var prev2: Double = 0.0
            var next1: Double = 0.0
            var next2: Double = 0.0
            
            if index - 2 >= 0 {
                prev2 = (activities[index - 2].actEng ?? 0) * (1/25)
            }
            if index - 1 >= 0 {
                prev1 = (activities[index - 1].actEng ?? 0) * (1/5)
            }
            let current = record.actEng ?? 0
            if index + 1 < activities.count {
                next1 = (activities[index + 1].actEng ?? 0) * (1/5)
            }
            if index + 2 < activities.count {
                next2 = (activities[index + 2].actEng ?? 0) * (1/25)
            }
            
            let sum = prev2 + prev1 + current + next1 + next2
            record.actEng = sum
//            print("\(record.startDate.formatted());"
//                  + "\(record.hr ?? 0);"
//                  + "\(sum);"
//            )
        }
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
        
        processActivities(&activities)
        
        return activities
    }
}
