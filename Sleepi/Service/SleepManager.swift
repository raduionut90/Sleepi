//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "SleepManager"
)

@MainActor
class SleepManager: ObservableObject {
    
    private var healthStore: HealthStore?
    @Published var nightSleeps: [Sleep] = []
    @Published var naps: [Sleep] = []

    init(date: Date){
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func refreshSleeps(date: Date) async throws {
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
                        let activities: [Record] = Utils.getActivitiesFromRawData(heartRates: heartRates, activeEnergy: activeEnergys)
                        let epochs = Utils.getEpochs(activities: activities, minutes: 3)

                        let sleep: Sleep = Sleep(startDate: rawSleep.startDate, endDate: rawSleep.endDate, epochs: epochs)
                        tmpSleeps.append(sleep)
                        print("")
                    }
                    let sleeps = self.sleepFilter(sleeps: tmpSleeps, date: date)
                    self.nightSleeps = sleeps.nightSleep
                    self.naps = sleeps.naps
                    self.updateEpochsClasificationX()

                }
            }
//
//        print("sleeps refreshSleeps: \(nightSleeps.count)")
//        print("naps refreshSleeps: \(naps.count)")

    }
    
    private func updateEpochsClasificationX() {
        for sleep in nightSleeps {
            
            let activityQuartiles = Utils.getQuartiles(values: sleep.epochs.map {$0.sumActivity} )
            let hrQuartiles = Utils.getQuartiles(values: sleep.epochs.map {$0.meanHR} )
            
            logger.log(";\(activityQuartiles.firstQuartile);\(activityQuartiles.median);\(activityQuartiles.thirdQuartile)")
            logger.log(";\(hrQuartiles.firstQuartile);\(hrQuartiles.median);\(hrQuartiles.thirdQuartile)")
            
            for (index, epoch) in sleep.epochs.enumerated() {
                for record in epoch.records {
                    if record.hr != nil {
                        logger.log(";hrR;\(record.startDate.formatted());\(record.endDate.formatted());\(record.hr ?? 0)")
                    }
                }
//                logger.log(";\(epoch.startDate.formatted());\(epoch.endDate.formatted());\(epoch.sumActivity);\(epoch.meanHR)")
                let lastEpoch = sleep.epochs.indices.contains(index - 1) ? sleep.epochs[index - 1] : nil
                
                if lastEpoch != nil && !lastEpoch!.meanHR.isNaN {
                    if (epoch.meanHR < lastEpoch!.meanHR - 5 || epoch.meanHR < hrQuartiles.firstQuartile ) && epoch.sumActivity == 0 {
                        epoch.stage = SleepStage.DeepSleep
                    } else if ((epoch.meanHR > lastEpoch!.meanHR + 5 || epoch.meanHR >= hrQuartiles.thirdQuartile) ) || (epoch.sumActivity > 0.1 && epoch.meanHR.isNaN ){
                        epoch.stage = SleepStage.RemSleep
                    } else if (((lastEpoch!.meanHR - 2)...(lastEpoch!.meanHR + 2)).contains(epoch.meanHR) ||
                               lastEpoch!.meanHR.isNaN && epoch.meanHR.isNaN) &&
                                ((lastEpoch!.sumActivity - 0.05 ... lastEpoch!.sumActivity + 0.05).contains(epoch.sumActivity) ||
                                lastEpoch!.sumActivity.isNaN && epoch.sumActivity.isNaN)  {
                        epoch.stage = lastEpoch!.stage
                    } else {
                        epoch.stage = SleepStage.LightSleep
                    }
                } else {
                    if epoch.sumActivity == 0 && (epoch.meanHR < hrQuartiles.firstQuartile || epoch.meanHR.isNaN) {
                        epoch.stage = SleepStage.DeepSleep
                    } else if (epoch.meanHR >= hrQuartiles.thirdQuartile || epoch.meanHR.isNaN) && epoch.sumActivity > 0.2 {
                        epoch.stage = SleepStage.RemSleep
                    } else {
                        epoch.stage = SleepStage.LightSleep
                    }
                }
                

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
            $0.getStageSleepDuration(stage: stage)
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

