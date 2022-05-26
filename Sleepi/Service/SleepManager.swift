//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit
import SwiftUI

@MainActor
class SleepManager: ObservableObject {
    private var healthStore: HealthStore?
    @Published var currentDate: Date
    @Published var startSleep: Date = Date.init(timeIntervalSince1970: 0)
    @Published var endSleep: Date = Date.init(timeIntervalSince1970: 0)
    var sleepDuration: Double = 0
    let screenWidth: Double
    var heartRateAverage: Double = 0

    @Published var sleeps: [Sleep] = []
    @Published var naps: [[Sleep]] = []
    @Published var sleepPoints: [SleepPoint] = []

    

    init(date: Date, screenWidth: Double){
        self.currentDate = date
        self.screenWidth = screenWidth
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
        self.refreshSleeps(date: date)
                
    }
    
    func getSleptTime() -> DateComponents {
        let difference = Calendar.current.dateComponents([.hour, .minute], from: startSleep, to: endSleep)
        return difference
    }

    func calculateMinAndMaxSleepTime(_sleeps: [Sleep]) {
        if let earliest = _sleeps.min(by: { $0.startDate < $1.startDate }) {
            // use earliest reminder
            startSleep = earliest.startDate
        }
        if let latest = _sleeps.max(by: { $0.endDate < $1.endDate }) {
            // use earliest reminder
            endSleep = latest.endDate
        }
        sleepDuration = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
    }
    
    func getHourLabels() -> [HourItem] {
        var hours: [HourItem] = []
        let startHour = Calendar.current.component(.hour, from: startSleep)
        let endHour = Calendar.current.component(.hour, from: endSleep)
        let startMin = Calendar.current.component(.minute, from: startSleep)
        let endMin = Calendar.current.component(.minute, from: endSleep)

        if (startHour > endHour) {
            for h in startHour ... 24 {
                if h == 24{
                    hours.append(HourItem(value: String(0)))
                } else {
                    hours.append(HourItem(value: String(h)))

                }
            }
            for h in 1 ... endHour {
                hours.append(HourItem(value: String(h)))
            }
        } else {
            for h in startHour ... endHour {
                hours.append(HourItem(value: String(h)))
            }
        }
        
        var result: [HourItem] = []
        for hour in hours {
            if hour == hours.first {
                switch startMin {
                case 0...15:
                    result.append(hour)
                    result.append(HourItem(value: "x"))
                case 16...45:
                    result.append(HourItem(value: "x"))
                default:
                    continue
                }
            } else if hour == hours.last {
                switch endMin {
                case 0...15:
                    result.append(hour)
                case 16...45:
                    result.append(hour)
                    result.append(HourItem(value: "x"))
                default:
                    result.append(hour)
                    result.append(HourItem(value: "x"))
                    result.append(HourItem(value: String(Int(hour.value)! + 1)))

                }
            } else {
                result.append(hour)
                result.append(HourItem(value: "x"))
            }

        }
        return result
    }
    


    func getSleepPoints(sleeps: [Sleep]) {
        
        sleepPoints = []

        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)

        for sleep in sleeps {

            // when awake
            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && sleepDuration != 0){
                setSleepPoint(startValue: lastEndTime.timeIntervalSinceReferenceDate, endValue: sleep.startDate.timeIntervalSinceReferenceDate, sleepType: SleepType.Awake)

            }
            var startValue = sleep.startDate.timeIntervalSinceReferenceDate
            
            if sleep.heartRates.count > 2 {
                for heartRate in sleep.heartRates {
                    var sleepType: SleepType
//                    print(((10/100) * heartRateAverage))
                    if heartRate.value < heartRateAverage - ((10/100) * heartRateAverage) {
                        
                        sleepType = SleepType.DeepSleep
                    } else if heartRate.value > heartRateAverage + ((10/100) * heartRateAverage) {
                        sleepType = SleepType.RemSleep
                    } else {
                        sleepType = SleepType.LightSleep
                    }
                    
                    setSleepPoint(startValue: startValue, endValue: heartRate.startDate.timeIntervalSinceReferenceDate, sleepType: sleepType)
                    
                    startValue = heartRate.startDate.timeIntervalSinceReferenceDate
                }
            } else {
                setSleepPoint(startValue: startValue, endValue: sleep.endDate.timeIntervalSinceReferenceDate, sleepType: SleepType.DeepSleep)
            }
            
            lastEndTime = sleep.endDate
        }
    }
    
    func getHeartRateAverage(sleeps: [Sleep]) -> Double {
        var totalHr: [Int] = []

        for sleep in sleeps {
            let intHrs: [Int] = sleep.heartRates.map { Int($0.value) }

            totalHr.append(contentsOf: intHrs )
        }
        let result: Double = totalHr.count > 0 ? Double(totalHr.reduce(0, +) / totalHr.count) : 0

        return result
    }
    
    func setSleepPoint(startValue: Double, endValue: Double, sleepType: SleepType) {
        var offsetX = sleepPoints.last?.offsetX ?? 0
                
        let startPoint = SleepPoint(
            type: sleepType.rawValue,
            offsetX: offsetX)
        sleepPoints.append(startPoint)

        let sleepPercent = ((endValue - startValue) / sleepDuration )
        let offset = (sleepPercent) * screenWidth
        offsetX += offset

        let endPoint = SleepPoint(
            type: sleepType.rawValue,
            offsetX: offsetX)
        sleepPoints.append(endPoint)
    }
    
    func refreshSleeps(date: Date) {
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var tmpSleeps = await healthStore.startSleepQuery(date: date)
                    
                    for (index, sleep) in tmpSleeps.enumerated() {
                        let heartRates = await healthStore.startHeartRateQuery(startDate: sleep.startDate, endDate: sleep.endDate)
                        tmpSleeps[index].heartRates = heartRates
                    }
                    calculateMinAndMaxSleepTime(_sleeps: tmpSleeps)
                    self.heartRateAverage = getHeartRateAverage(sleeps: tmpSleeps)
                    getSleepPoints(sleeps: tmpSleeps)
                    self.sleeps = tmpSleeps
                    
                }

            }
            
        }
        
    }
}
