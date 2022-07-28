//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit
import os

@MainActor
class SleepManager: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SleepManager.self)
    )
    
    private var healthStore: HealthStore?
    @Published var nsHeartRateAverage: Double = 0.0
    @Published var nightSleeps: [Sleep] = []
    @Published var naps: [Sleep] = []
    
    init(date: Date){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func refreshSleeps(date: Date) {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var tmpSleeps: [Sleep] = []
                    var startDate = Calendar.current.startOfDay(for: date)
                    startDate = Calendar.current.date(byAdding: .hour, value: -4, to: startDate)!
                    let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
                    
                    let rawSleeps: [HKCategorySample] = await healthStore.getSleeps(startTime: startDate, endTime: endDate)
                    for rawSleep in rawSleeps {
                        let activities: [Activity] = await self.getActivitiesFromRawData(healthStore, rawSleep.startDate, rawSleep.endDate)
                        let sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate, activities: activities)
                        updateActivityEndDate(sleep)
                        tmpSleeps.append(sleep)
                    }
                    let sleeps = self.sleepFilter(sleeps: tmpSleeps, date: date)
                    self.nsHeartRateAverage = getNightSleepsHeartRateAverage(sleeps: sleeps.nightSleep)
                    self.updateActivityStage(sleeps.nightSleep)
                    self.updateActivityStage(sleeps.naps)
                    self.nightSleeps = sleeps.nightSleep
                    self.naps = sleeps.naps
                }
            }
        }
        
//        print("sleeps refreshSleeps: \(sleeps.count)")
//        print("naps refreshSleeps: \(naps.count)")

    }
    
    private func updateActivityStage(_ sleeps: [Sleep]) {
        for sleep in sleeps {
            Self.logger.debug("hravr: \(self.nsHeartRateAverage)")
            for activity in sleep.activities {
                activity.setStage(nsHeartRateAverage)
            }
        }
    }
    
    private func updateActivityEndDate(_ sleep: Sleep) {
        for (index, activity) in sleep.activities.enumerated() {
            activity.endDate = sleep.activities.indices.contains(index + 1) ? sleep.activities[index + 1].startDate : sleep.endDate
        }
    }
    
    private func sleepFilter(sleeps: [Sleep], date: Date) -> (nightSleep: [Sleep], naps: [Sleep]) {
        var nightSleep: [Sleep] = []
        var naps: [Sleep] = []
        var referenceHour = Calendar.current.startOfDay(for: date)
        referenceHour = Calendar.current.date(byAdding: .hour, value: 10, to: referenceHour)!
        
        for sleep in sleeps {
            if sleep.startDate > referenceHour {
                naps.append(sleep)
            } else {
                nightSleep.append(sleep)
            }
        }
        return (nightSleep, naps)
    }
    
    func getInBedTime() -> Double {
        if nightSleeps.isEmpty {
            return 0.0
        }
        let startDate: Date = (self.nightSleeps.first?.startDate)!
        let endDate: Date = (self.nightSleeps.last?.endDate)!
        return endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
    }
    
    func getSleepStageDuration(stage: SleepStage) -> TimeInterval {
        if stage == .Awake {
            return zip(nightSleeps, nightSleeps.dropFirst())
                .map({
                    $1.startDate.timeIntervalSinceReferenceDate - $0.endDate.timeIntervalSinceReferenceDate
                }).reduce(0, +)
        }
        return self.nightSleeps.map({
            $0.getStageSleepDuration(allSleepsHrAverage: self.nsHeartRateAverage, stage: stage)
        }).reduce(0, +)
    }
    
    func getSleepDuration(type: SleepType) -> Double {
        var result: Double = 0.0
        switch type {
        case .NightSleep:
            for sleep in self.nightSleeps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        case .Nap:
            for sleep in self.naps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        case .All:
            for sleep in self.nightSleeps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
            for sleep in self.naps {
                result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
            }
        }

        return result
    }

    private func getNightSleepsHeartRateAverage(sleeps: [Sleep]) -> Double {
        var sum: Double = 0.0
        for sleep in sleeps {
            sum += sleep.heartRateAverage
        }
        return sum / Double(sleeps.count)
    }
    
    private func getActivitiesFromRawData(_ healthStore: HealthStore, _ startDate: Date, _ endDate: Date) async -> [Activity] {
        var activities: [Activity] = []
        
//        let heartRates = await healthStore.startHeartRateQuery(startDate: startDate, endDate: endDate)
        let heartRates = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .heartRate)
//        let activeEnergys = await healthStore.activeEnergyQuery(startDate: startDate, endDate: endDate)
//        let hrvs = await healthStore.startHeartRateVariabilityQuery(startDate: startDate, endDate: endDate)
//        let rhrs = await healthStore.startRestingHeartRateQuery(startDate: startDate, endDate: endDate)
//        let respRates = await healthStore.startRespiratoryRateQuery(startDate: startDate, endDate: endDate)
        
        for heartRate in heartRates {
            let record = Activity(startDate: heartRate.startDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
            activities.append(record)
        }
//        for act in activeEnergys {
//            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
//                                                Utils.dateTimeformatter.string(from: act.startDate)} ) {
//                existingRecord.actEng = act.quantity.doubleValue(for: HKUnit.kilocalorie())
//            } else {
//                let record = Activity(startDate: act.startDate, actEng: act.quantity.doubleValue(for: HKUnit.kilocalorie()))
//                activities.append(record)
//            }
//        }
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
//            if let existingRecord = activities.first(where: { rhr.startDate >= $0.startDate } ) {
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

enum SleepType: Double {
    case NightSleep
    case Nap
    case All
}
