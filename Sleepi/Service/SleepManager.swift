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
    
    fileprivate func getHeartRateAveragePerDay(_ healthStore: HealthStore, _ startDate: Date, _ endDate: Date) async -> Double{
        let heartRatesAllDay = await healthStore.getSamples(startDate: startDate, endDate: endDate, type: .heartRate)
        return heartRatesAllDay.map( { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ).reduce(0, +) / Double(heartRatesAllDay.count)
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
                        let heartRates = await healthStore.getSamples(startDate: rawSleep.startDate, endDate: rawSleep.endDate, type: .heartRate)
                        let activeEnergys = await healthStore.getSamples(startDate: rawSleep.startDate, endDate: rawSleep.endDate, type: .activeEnergyBurned)
                        let activities: [Records] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergys)
                        let epochs = Utils.getEpochsFromActivitiesByTimeInterval(start: rawSleep.startDate, end: rawSleep.endDate, activities: activities, minutes: 10)

                        let sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate, epochs: epochs)
                        tmpSleeps.append(sleep)
                        print("")
                    }
                    let sleeps = self.sleepFilter(sleeps: tmpSleeps, date: date)
                    self.nsHeartRateAverage = getNightSleepsHeartRateAverage(sleeps: sleeps.nightSleep)
                    self.nightSleeps = sleeps.nightSleep
                    self.naps = sleeps.naps
                    self.updateEpochsClasification()
                }
            }
        }
//
//        print("sleeps refreshSleeps: \(nightSleeps.count)")
//        print("naps refreshSleeps: \(naps.count)")

    }
    
    private func updateEpochsClasification() {
        let allSleepsEpochs = self.nightSleeps.flatMap {$0.epochs}
        
        let activityQuartiles = Utils.getQuartiles(values: allSleepsEpochs.map {$0.sumActivity} )
        let hrQuartiles = Utils.getQuartiles(values: allSleepsEpochs.map {$0.meanHR} )
        
        for epoch in allSleepsEpochs {
            let maxHr = epoch.records.compactMap({ $0.hr }).max() ?? epoch.meanHR
            let minHr = epoch.records.compactMap({ $0.hr }).min() ?? epoch.meanHR
            if epoch.sumActivity <= activityQuartiles.firstQuartile && minHr <= hrQuartiles.firstQuartile {
                epoch.sleepClasification = SleepStage.DeepSleep
            } else if maxHr >= hrQuartiles.thirdQuartile {
                epoch.sleepClasification = SleepStage.RemSleep
            } else {
                epoch.sleepClasification = SleepStage.LightSleep
            }
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
    
}

enum SleepType: Double {
    case NightSleep
    case Nap
    case All
}
