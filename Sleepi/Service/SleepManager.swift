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
    var timeDiff: Double = 0
    let screenWidth: Double

    @Published var sleeps: [Sleep] = []
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
        timeDiff = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
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

    func getSleepPoints(screenWidth: Double) -> [SleepPoint] {
        var sleepPoints = [SleepPoint]()
        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)

        print("Sleeps.count.getp: " + "\(sleeps.count)")

        print("timeDiff: " + "\(timeDiff)")
        print("Sleeps.count.getp: " + "\(sleeps.count)")

//        if (sleeps.count == 0 || timeDiff == 0) {
//            return []
//        }

        var offsetX: Double = 0
        for sleep in sleeps {
            print(sleep.startDate)
            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && timeDiff != 0){
                print("lastEndTime: " + "\(lastEndTime)")

                let sleepType = (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 10 * 60 ?
                SleepType.RemSleep.rawValue : SleepType.Awake.rawValue

                print("type: \((sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 160)")
                print("type: \((lastEndTime.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) )")

                let startPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(startPoint)

                let sleepPercent: Double = ( (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) / timeDiff )
                let offset = (sleepPercent) * screenWidth
                offsetX += offset

                let endPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(endPoint)

            }

            let startPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(startPoint)

            let sleepPercent = ((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) / timeDiff )
            let offset = (sleepPercent) * screenWidth
            offsetX += offset

            let endPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(endPoint)

            lastEndTime = sleep.endDate
        }

        return sleepPoints
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
                            self.sleepPoints = self.getSleepPoints(screenWidth: self.screenWidth)
                        }
                    }

                }
            }
        }
        
    }
    
}
