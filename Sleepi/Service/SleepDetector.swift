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
                        print("\(actQuartiles.firstQuartile);\(actQuartiles.median);\(actQuartiles.thirdQuartile)")
                        print("\(hrQuartiles.firstQuartile);\(hrQuartiles.median);\(hrQuartiles.thirdQuartile)")
                        print("")
//                        let median = quariles[Constants.MEDIAN]!
//                        let thirdQuartile = quariles[Constants.THIRD_QUARTILE]!
                        let potentialSleeps = identifySleeps(activities: activities, quartile: actQuartiles, lastSleepEndDate: lastSleepEndDate)
//                        let finalSleeps = potentialSleeps.filter({
//                            $0.heartRateAverage < hrQuartiles.firstQuartile ||
//                            Utils.isLowTrending(heartRates: $0.epochs.compactMap {$0.records}.compactMap {$0.} )
//                        })
                        
                        for sleep in potentialSleeps {
//                            print(sleep)
//                            print(hrQuartiles)
//                            print(Utils.isLowTrending(heartRates: heartRates))
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

    private func identifySleeps(activities: [Records], quartile: (firstQuartile: Double, median: Double, thirdQuartile: Double), lastSleepEndDate: Date) -> [Sleep] {
        var sleeps: [Sleep] = []
        var tmpSleeps: [Sleep] = []
        let firstActivityIndex = activities.firstIndex(where: { $0.startDate > lastSleepEndDate }) ?? 0
        
        var startDate: Date?
        var lowActivityEpochs: [Epoch] = []
        let epochs = Utils.getEpochsFromActivities(activities: Array(activities[firstActivityIndex...]), epochLenght: 1)
        
        for epoch in epochs {
            print("\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.meanActivity);\(epoch.meanHR)")
            
            //            if epoch.records.contains(where: {$0.startDate.formatted() == "23.08.2022, 2:07"}){
            //                print("")
            //            }
            //
            // detecting sleep starting with epoch.activity < Q1
            if epoch.meanActivity.isNaN || epoch.meanActivity < quartile.median && !epoch.records.contains(where: { $0.firstAfterGap ?? false }){
                if startDate == nil {
                    startDate = epoch.records.first?.startDate
                }
                lowActivityEpochs.append(epoch)
            } else {
                if startDate != nil && !lowActivityEpochs.isEmpty {
                    
                    if (lowActivityEpochs.last!.records.last!.endDate.timeIntervalSinceReferenceDate) - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
                        tmpSleeps.append(Sleep(startDate: startDate!, endDate: lowActivityEpochs.last!.records.last!.endDate, epochs: lowActivityEpochs))
                    }
                    startDate = nil
                    lowActivityEpochs = []
                }
            }
            if epoch == epochs.last && startDate != nil && (epoch.records.last?.startDate.timeIntervalSinceReferenceDate)! - startDate!.timeIntervalSinceReferenceDate > Constants.MINI_SLEEP_DURATION {
                tmpSleeps.append(Sleep(startDate: startDate!, endDate: epoch.records.last!.endDate, epochs: lowActivityEpochs))
            }
        }
        
        sleeps = getConcatenatedSleeps(sleeps: tmpSleeps)
        sleeps = sleeps.filter( {$0.getDuration() >= Constants.SLEEP_DURATION} )
        sleeps = getSleepEpochs(sleeps: sleeps, epochs: epochs)
        sleeps = filterSleepByHr(sleeps: sleeps, epochs: epochs)
        sleeps = filterByLowActivityPercent(sleeps: sleeps, quartile: quartile)
        return sleeps
    }
    
    private func filterSleepByHr(sleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {

            let lastEpochs = epochs.reversed().filter({!$0.meanHR.isNaN}).first(where: {$0.startDate < sleep.startDate})
            let nextEpochs = epochs.filter({!$0.meanHR.isNaN}).first(where: {$0.startDate > sleep.endDate})
            // 95% from max
            let maxHr = max(lastEpochs?.meanHR ?? 0, nextEpochs?.meanHR ?? 0) * 0.95
            if sleep.heartRateAverage < maxHr {
                result.append(sleep)
            } else {
                print("Sleep: \(sleep.startDate.formatted()) - \(sleep.endDate.formatted()) ignored due to HR \(sleep.heartRateAverage), maxHR: \(maxHr)")
            }

        }
        return result
    }
    
    private func getSleepEpochs(sleeps: [Sleep], epochs: [Epoch]) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let firstEpoch = epochs.firstIndex {$0.startDate >= sleep.startDate}!
            let lastEpoch = (epochs.firstIndex {$0.endDate >= sleep.endDate})! - 1
            let sleepEpochs = Array(epochs[firstEpoch...lastEpoch])
            let newSleep = Sleep(startDate: sleep.startDate, endDate: sleep.endDate, epochs: sleepEpochs)
            result.append(newSleep)
        }
        return result
    }
    
    private func filterByLowActivityPercent(sleeps: [Sleep], quartile: (firstQuartile: Double, median: Double, thirdQuartile: Double)) -> [Sleep] {
        var result: [Sleep] = []
        for sleep in sleeps {
            let highActivities = sleep.epochs.filter( { !$0.meanActivity.isNaN && $0.meanActivity > quartile.firstQuartile} ).count
            let lowActTotalWithNan = sleep.epochs.count
            let percent: Double = Double(highActivities) / Double(lowActTotalWithNan) * 100.0
            print("\(sleep.startDate.formatted());\(sleep.endDate.formatted());percent;\(percent)")
            if percent < 35 {
                result.append(sleep)
            }
        }
        return result
    }
    
    private func getConcatenatedSleeps(sleeps: [Sleep]) -> [Sleep] {
        var result: [Sleep] = []
        for (index, sleep) in sleeps.enumerated() {
            if sleeps.indices.contains(index - 1) {
                if sleep.startDate.timeIntervalSinceReferenceDate - (result.last?.endDate.timeIntervalSinceReferenceDate)! < 600 {
                    let newSleep = Sleep(startDate: result.last!.startDate, endDate: sleep.endDate, epochs: [])
                    result.removeLast()
                    result.append(newSleep)
                } else {
                    result.append(sleep)
                }
            } else {
                result.append(sleep)
            }
        }
        return result
    }
    
    private func getStartDate(_ currentDate: Date) -> Date {
        var result = Calendar.current.startOfDay(for: currentDate)
        result = Calendar.current.date(byAdding: .day, value: -1, to: result)!
        result = Calendar.current.date(byAdding: .hour, value: 9, to: result)!
        return result
    }
    
}
