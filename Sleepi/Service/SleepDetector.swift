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
                        let lastSleepEndDate = sleeps.last?.endDate ?? aDayBefore
                        let heartRates = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .heartRate)
                        let activeEnergy = await healthStore.getSamples(startDate: aDayBefore, endDate: currentDate, type: .activeEnergyBurned)
//                      let hrv = await healthStore.startHeartRateVariabilityQuery(startDate: startDate, endDate: endDate)
//                      let rhr = await healthStore.startRestingHeartRateQuery(startDate: startDate, endDate: endDate)
//                      let resp = await healthStore.startRespiratoryRateQuery(startDate: startDate, endDate: endDate)
//                        let dailyMeanHr = heartRates.map( { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ).reduce(0, +) / Double(heartRates.count)
                        
                        let activities: [Records] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergy)
                        let sortedActivEnergy = activities.filter( { $0.actEng != nil } ).map({ $0.actEng! } )
                        let actQuartiles = Utils.getQuartiles(values: sortedActivEnergy)
                        let hrQuartiles = Utils.getQuartiles(values: activities.filter( { $0.hr != nil } ).map({ $0.hr! } ))
                        print("act: \(actQuartiles)")
                        print("hr: \(hrQuartiles)")

//                        let median = quariles[Constants.MEDIAN]!
//                        let thirdQuartile = quariles[Constants.THIRD_QUARTILE]!
                        
                        let potentialSleeps = identifySleeps(activities: activities, quartile: actQuartiles, lastSleepEndDate: lastSleepEndDate)
//                        let finalSleeps = potentialSleeps.filter({
//                            $0.heartRateAverage < hrQuartiles.firstQuartile ||
//                            Utils.isLowTrending(heartRates: $0.epochs.compactMap {$0.records}.compactMap {$0.} )
//                        })
                        
                        for sleep in potentialSleeps {
//                            print(sleep)
                            let heartRates: [Double] = sleep.epochs.flatMap {$0.records.compactMap {$0.hr} }
//
//                            print(sleep.heartRateAverage)
//                            print(hrQuartiles)
//                            print(Utils.isLowTrending(heartRates: heartRates))
                            if sleep.heartRateAverage < hrQuartiles.median || sleep.heartRateAverage < hrQuartiles.median && Utils.isLowTrending(heartRates: heartRates)  {
                                    healthStore.saveSleep(startTime: sleep.startDate, endTime: sleep.endDate)
                                }
                        }
                        
                        currentDate = aDayBefore
                        aDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: aDayBefore)!
                        if aDayBefore < Calendar.current.date(byAdding: .day, value: -14, to: Date())! {
                            break
                        }
                        
                        print("")
                    }

                    self.loading = false
                }
            }
        }
    }

    
    private func identifySleeps(activities: [Records], quartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), lastSleepEndDate: Date) -> [Sleep] {
        var sleeps: [Sleep] = []
        let firstActivityIndex = activities.firstIndex(where: { $0.startDate > lastSleepEndDate }) ?? 0
//        let relevantActivities = activities[firstActivityIndex...]
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []
        let epochs = Utils.getEpochsFromActivities(activities: Array(activities[firstActivityIndex...]), epochLenght: 1)
        
//        epochs = epochs.filter({ !$0.meanActivity.isNaN })
//        print("firstQuartile: \(quartile)")
        
        for (index, epoch) in epochs.enumerated() {
//            print("\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.meanActivity);\(epoch.meanHR)")
            
            if epoch.records.contains(where: {$0.startDate.formatted() == "20.08.2022, 23:42"}){
                print("")
            }
            
            // detecting sleep starting with epoch.activity < Q1
            if epoch.meanActivity.isNaN || epoch.meanActivity < quartile.firstQuartile && !epoch.records.contains(where: { $0.firstAfterGap ?? false }){
                if startDate == nil {
                    startDate = epoch.records.first?.startDate
                }
                lowActivityEpochs.append(epoch)

            } else if // last < Q1
                (epochs.indices.contains(index - 1) ? (epochs[index - 1].meanActivity.isNaN || epochs[index - 1].meanActivity < quartile.firstQuartile) : false) &&
                    (epoch.meanActivity < quartile.median || epoch.meanActivity.isNaN) &&
                    !epoch.records.contains(where: { $0.firstAfterGap ?? false }) {
                if startDate != nil {
                    lowActivityEpochs.append(epoch)
                }
            } else if //last < median and last -2 is < Q1 || nan and current < med
                (epochs.indices.contains(index - 1) ? epochs[index - 1].meanActivity.isNaN || epochs[index - 1].meanActivity < quartile.thirdQuartile : false) &&
                (epochs.indices.contains(index - 2) ? epochs[index - 2].meanActivity.isNaN || epochs[index - 2].meanActivity < quartile.firstQuartile : false) &&
                    (epoch.meanActivity < quartile.median || epoch.meanActivity.isNaN) &&
                !epoch.records.contains(where: { $0.firstAfterGap ?? false }) {
                if startDate != nil {
//                    print("lastEpoch: q1: \(quartile.firstQuartile) med: \(quartile.median)")
//                    print(epochs[index - 2].meanActivity)
//                    print(epochs[index - 1].meanActivity)
//                    print(epoch.meanActivity)
                    lowActivityEpochs.append(epoch)
                }
            }
            else {
                if startDate != nil && !lowActivityEpochs.isEmpty {
                    //20 min interval = 1200
                    let lastLowRecord = lowActivityEpochs.lastIndex(where: {$0.meanActivity.isNaN || $0.meanActivity < quartile.firstQuartile})!
                    let potentialSleepAfterFiltering = lowActivityEpochs[...lastLowRecord]
                    let highActivities = lowActivityEpochs.filter( {$0.meanActivity != nil && $0.meanActivity > quartile.firstQuartile} ).count

                    if (lowActivityEpochs.last!.records.last!.startDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.MIN_SLEEP_DURATION {
                        print("\(lowActivityEpochs.first!.startDate.formatted()); \((potentialSleepAfterFiltering.last?.endDate.formatted())!)")
                        print("high: \(highActivities); total: \(lowActivityEpochs.count);")
                        let p: Double = Double(highActivities) / Double(lowActivityEpochs.count) * 100.0
                        print("percent: \(p);")

                        print("")
                        sleeps.append(Sleep(startDate: startDate!, endDate: lowActivityEpochs.last!.records.last!.endDate, epochs: lowActivityEpochs))
                    }
                    startDate = nil
                    lowActivityEpochs = []
                }
            }
            if epoch == epochs.last && startDate != nil && (epoch.records.last?.startDate.timeIntervalSinceReferenceDate)! - startDate!.timeIntervalSinceReferenceDate > Constants.MIN_SLEEP_DURATION {
                sleeps.append(Sleep(startDate: startDate!, endDate: epoch.records.last!.endDate, epochs: lowActivityEpochs))
            }
        }
        return sleeps
    }
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
