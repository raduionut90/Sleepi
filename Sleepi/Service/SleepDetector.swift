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

                    var currentDate = Date()
                    var aDayBefore = getStartDate(currentDate)
                    
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
                    var sleeps: [HKCategorySample] = []
                    
                    while sleeps.isEmpty {
                        sleeps = await healthStore.getSleeps(startTime: aDayBefore, endTime: currentDate)
                        let heartRates = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .activeEnergyBurned)
//                      let hrv = await healthStore.startHeartRateVariabilityQuery(startDate: startDate, endDate: endDate)
//                      let rhr = await healthStore.startRestingHeartRateQuery(startDate: startDate, endDate: endDate)
//                      let resp = await healthStore.startRespiratoryRateQuery(startDate: startDate, endDate: endDate)
                        let dailyMeanHr = heartRates.map( { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ).reduce(0, +) / Double(heartRates.count)
                        
                        let activities: [Activity] = self.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy, hrvs: [], rhrs: [], respRates: [])
                        let sortedActivEnergy = activities.map({ $0.actEng ?? 0 } ).filter({ $0 > 0.0 }).sorted(by: <)
                        let quariles = getQuartiles(values: sortedActivEnergy)

                        print(quariles)
                        
                        let firstQuartile = quariles[Constants.FIRST_QUARTILE]!
                        let median = quariles[Constants.MEDIAN]!
                        let thirdQuartile = quariles[Constants.THIRD_QUARTILE]!
                        
                        var detectedPairs = sleepDetection(activities: activities, firstQuartile: firstQuartile, thirdQuartile: thirdQuartile)
                        if sleeps.count > 0 {
                            //filter by last sleep date
                            detectedPairs = detectedPairs.filter( { $0.key.startDate > (sleeps.last?.endDate)! } )
                        }
                        let filteredSleep = removeShortSleepPairs(pairs: detectedPairs)
                        let potentialSleeps = evaluateActivitiesForPairs(pairs: filteredSleep, activities: activities, quartile: firstQuartile)

                        let finalSleeps = potentialSleeps.filter({$0.heartRateAverage < dailyMeanHr})
                        
                        for sleep in finalSleeps {
//                            print(sleep)
                            healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                        }
                        
                        currentDate = aDayBefore
                        aDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: aDayBefore)!
                        if aDayBefore < Calendar.current.date(byAdding: .day, value: -14, to: Date())! {
                            break
                        }
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
    
    private func evaluateActivitiesForPairs(pairs: [Activity: Activity], activities: [Activity], quartile: Double) -> [Sleep] {
        var sleeps: [Sleep] = []
        for pair in pairs {
            print("")
            print("start: \(pair.key.startDate.formatted())")
            let startIndex = activities.firstIndex(where: {$0 == pair.key })!
            let endIndex = activities.firstIndex(where: {$0 == pair.value })!
            let totalActivitiesPerInterval = Array(activities[startIndex..<endIndex])

                for activity in totalActivitiesPerInterval {
                    print("\(activity.startDate.formatted());"
                          + "\(activity.hr ?? 0);"
                          + "\(activity.actEng ?? 0);"
                    )
                }
            var counter = 0
            var startDate: Date?
            var epochActivities: [Activity] = []
            while counter < totalActivitiesPerInterval.count {
                let offset = counter + 5 > totalActivitiesPerInterval.count - 1 ? totalActivitiesPerInterval.count : counter + 5
                let epoch = totalActivitiesPerInterval[counter..<offset]
                let epochMeanAct = epoch.compactMap({ $0.actEng }).reduce(0.0, +) / Double(epoch.compactMap({ $0.actEng }).count)
                if epochMeanAct < quartile {
                    if startDate == nil {
                        startDate = epoch.first?.startDate
                    }
                    epochActivities.append(contentsOf: epoch)
                } else {
                    if startDate != nil {
                        //20 min interval = 1200
                        if (epoch.first?.startDate.timeIntervalSinceReferenceDate)! - startDate!.timeIntervalSinceReferenceDate > Constants.MIN_SLEEP_DURATION {
                            sleeps.append(Sleep(startDate: startDate!, endDate: epoch.first!.startDate, activities: epochActivities))
                        }
                        startDate = nil
                        epochActivities = []
                    }

                }
                
                counter += 5
                if counter >= totalActivitiesPerInterval.count - 1 {
                    if startDate != nil && (epoch.first?.startDate.timeIntervalSinceReferenceDate)! - startDate!.timeIntervalSinceReferenceDate > Constants.MIN_SLEEP_DURATION {
                        sleeps.append(Sleep(startDate: startDate!, endDate: epoch.first!.startDate, activities: epochActivities))
                    }
                    break
                }
            }
            print("pairs: \(pair.key.startDate.formatted());\(pair.value.startDate.formatted())")
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
                if acts.count == 0 {
                    print("break")
                    break
                }
                let endAct = acts.first(where: { $0.actEng ?? 99 >  thirdQuartile || ($0.firstAfterGap ?? false == true) } ) ?? acts.last!
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
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
    fileprivate func processActivities(_ activities: inout [Activity]) {
        for (index, activity) in activities.enumerated() {
            var prev1: Double = 0.0
            var prev2: Double = 0.0
            var next1: Double = 0.0
            var next2: Double = 0.0
            
            if index - 2 >= 0 {
                prev2 = (activities[index - 2].actEng ?? 0) * (1/25)
            }
            if index - 1 >= 0 {
                prev1 = (activities[index - 1].actEng ?? 0) * (1/5)
                if activity.startDate.timeIntervalSinceReferenceDate - activities[index - 1].startDate.timeIntervalSinceReferenceDate > 600 {
                    activities[index - 1].firstAfterGap = true
                }
            }
            let current = activity.actEng ?? 0
            if index + 1 < activities.count {
                next1 = (activities[index + 1].actEng ?? 0) * (1/5)
            }
            if index + 2 < activities.count {
                next2 = (activities[index + 2].actEng ?? 0) * (1/25)
            }
            
            let sum = prev2 + prev1 + current + next1 + next2
            activity.actEng = sum
//            print("\(activity.startDate.formatted());"
//                  + "\(activity.hr ?? 0);"
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
//            if let existingRecord = activities.first(where: { $0.startDate == heartRate.startDate } ) {
//                existingRecord.hr = heartRate.quantity.doubleValue(for: HKUnit(from: "count/min"))
//            } else {
            let record = Activity(startDate: heartRate.startDate, endDate: heartRate.endDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
                activities.append(record)
//            }
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
