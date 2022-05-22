//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit

class SleepManager: ObservableObject {
    private var healthStore: HealthStore?
    var currentDate: Date
    var startSleep: Date = Date.init(timeIntervalSince1970: 0)
    var endSleep: Date = Date.init(timeIntervalSince1970: 0)
    var sleepDuration: Double = 0
    let screenWidth: Double
    var heartRates: [HeartRate] = []

    @Published var sleeps: [Sleep] = []
    @Published var naps: [[Sleep]] = []

    @Published var sleepPoints: [SleepPoint] = []

    

    init(date: Date, screenWidth: Double){
        self.currentDate = date
        self.screenWidth = screenWidth
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
        refreshSleeps(date: date)
                
    }
    
    func refreshSleeps(date: Date) {
        Task {
            await readSleeps(date: date)
        }
    }
    
    func getSleptTime() -> DateComponents {
        let difference = Calendar.current.dateComponents([.hour, .minute], from: startSleep, to: endSleep)
        return difference
    }

    func calculateMinAndMaxSleepTime() {
        if let earliest = sleeps.min(by: { $0.startDate < $1.startDate }) {
            // use earliest reminder
            startSleep = earliest.startDate
        }
        if let latest = sleeps.max(by: { $0.endDate < $1.endDate }) {
            // use earliest reminder
            endSleep = latest.endDate
        }
        sleepDuration = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
    }
    
    func getHourLabels() -> [String] {
        var hours: [Int] = []
        let startHour = Calendar.current.component(.hour, from: startSleep)
        let endHour = Calendar.current.component(.hour, from: endSleep)

        if (startHour > endHour) {
            for h in startHour ... 24 {
                if h == 24{
                    hours.append(0)
                } else {
                    hours.append(h)

                }
            }
            for h in 1 ... endHour {
                hours.append(h)
            }
        } else {
            for h in startHour ... endHour {
                hours.append(h)
            }
        }
        return hours.map { String($0) }
    }

    func getSleepPoints() {
        var sleepPoints = [SleepPoint]()
        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)

        var offsetX: Double = 0
        for sleep in sleeps {

            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && sleepDuration != 0){

                let sleepType = (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 10 * 60 ?
                SleepType.RemSleep.rawValue : SleepType.Awake.rawValue

                let startPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(startPoint)

                let sleepPercent: Double = ( (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) / sleepDuration )
                let offset = (sleepPercent) * screenWidth
                offsetX += offset

                let endPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(endPoint)

            }
            
//            for heartRate in heartRates {
//                
//            }
            let startPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(startPoint)

            let sleepPercent = ((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) / sleepDuration )
            let offset = (sleepPercent) * screenWidth
            offsetX += offset

            let endPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(endPoint)

            lastEndTime = sleep.endDate
        }

        self.sleepPoints = sleepPoints
    }
    
    func loadHeartRates() {
        for (index, sleep) in sleeps.enumerated() {
            healthStore?.startHeartRateQuery(startDate: sleep.startDate, endDate: sleep.endDate) { samples in
                var hrs: [HeartRate] = []
                for sample in samples ?? [] {
                    print(sample)
                    let hr = HeartRate(value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")), startDate: sample.startDate)
                    hrs.append(hr)
                }
                DispatchQueue.main.async {
                    self.sleeps[index].heartRates = hrs
                }
                
            }
        }
//        healthStore?.startHeartRateQuery(startDate: self.startSleep, endDate: self.endSleep) { samples in
//            for sample in samples ?? [] {
//                print(sample)
//                let hr = HeartRate(value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")), startDate: sample.startDate)
//                self.heartRates.append(hr)
//            }
//        }

    }
    
    func readSleeps(date: Date) async {
        DispatchQueue.main.async {
            self.sleeps = []
        }
        
        if let healthStore = healthStore {
            healthStore.requestAuthorization{ success in
                if success {
                    healthStore.startSleepQuery(date: date) { samples in
//                        print("samples.count: \(samples.count)")

                        for item in samples {
                            if let sample = item as? HKCategorySample {
                                if (sample.sourceRevision.source.bundleIdentifier.contains("com.apple.health") &&
                                    ((sample.sourceRevision.productType?.contains("Watch")) == true)) {
                                    
                                    let sleep = Sleep(value: sample.value, startDate: sample.startDate, endDate: sample.endDate, source: sample.sourceRevision.source.name)
                                    
                                    DispatchQueue.main.async {
                                        self.sleeps.append(sleep)
                                    }
                                    
//                                    print("Healthkit sleep: \(sleep.startDate) \(sleep.endDate) value: \(value)")
//                                    print(sleep.value)
//                                    print(sample.sourceRevision)
//                                    print("")
                                }
                            }
                        
                        }
                        DispatchQueue.main.async {
                            self.calculateMinAndMaxSleepTime()
                            self.loadHeartRates()
                            self.getSleepPoints()
                        }
                        
                    }

                }
            }
        }
        
    }
    
}
