//
//  SleepManager.swift
//  Sleepi
//
//  Created by Ionut Radu on 18.05.2022.
//

import Foundation
import HealthKit

@MainActor
class SleepManager: ObservableObject {
    private var healthStore: HealthStore?
    var screenWidth: Double?
    @Published var sleepState: SleepState?
    var deepSleepTime: TimeInterval?
    var lightSleepTime: TimeInterval?
    var remSleepTime: TimeInterval?
    
    convenience init(date: Date, screenWidth: Double){
        self.init(date: date)
        self.screenWidth = screenWidth
    }
    
    init(date: Date){
        self.screenWidth = 0
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HealthStore()
        }
    }
    
    func refreshSleeps(date: Date) {
        deepSleepTime = TimeInterval()
        lightSleepTime = TimeInterval()
        remSleepTime = TimeInterval()
        
        Task.init {
            if let healthStore = healthStore {
                let authorized: Bool = try await healthStore.requestAuthorization()
                if authorized {
                    var tmpSleeps = await healthStore.startSleepQuery(date: date)
                    for (index, sleep) in tmpSleeps.enumerated() {
                        let heartRates = await healthStore.startHeartRateQuery(startDate: sleep.startDate, endDate: sleep.endDate)
                        tmpSleeps[index].heartRates = heartRates
                    }
                    
                    var sleepCalculation: (startSleep: Date, endSleep: Date, sleepDuration: TimeInterval, totalTime: TimeInterval) = (
                        startSleep: Date.init(timeIntervalSince1970: 0),
                        endSleep: Date.init(timeIntervalSince1970: 0),
                        sleepDuration: 0,
                        totalTime: 0
                    )
                    var heartRateAverage: Double = 0
                    var sleepPoints: [SleepPoint] = []
                    var hoursLabels: [HourItem] = []
                    
                    if tmpSleeps.count > 1 {
                        sleepCalculation = self.calculateMinAndMaxSleepTime(sleeps: tmpSleeps)
                        heartRateAverage = getHeartRateAverage(sleeps: tmpSleeps)
                        sleepPoints = getSleepPoints(sleeps: tmpSleeps,
                                                     sleepDuration: sleepCalculation.sleepDuration,
                                                     heartRateAverage: heartRateAverage)
                        hoursLabels = self.getHourLabels(startSleep: sleepCalculation.startSleep,
                                                         endSleep: sleepCalculation.endSleep)
                    }
                    var state = SleepState(sleeps: tmpSleeps,
                                           naps: [[Sleep]()],
                                           sleepPoints: sleepPoints,
                                           startSleep: sleepCalculation.startSleep,
                                           endSleep: sleepCalculation.endSleep,
                                           sleepDuration: sleepCalculation.sleepDuration,
                                           screenWidth: self.screenWidth!,
                                           heartRateAverage: heartRateAverage,
                                           hoursLabels: hoursLabels,
                                           totalBedTime: sleepCalculation.totalTime)
                    state.sleepTime = self.getSleepTimeInterval(sleeps: tmpSleeps)
                    state.awakeTime = self.getAwakeDuration(sleeps: tmpSleeps)
                    state.deepSleepTime = self.deepSleepTime
                    state.lightSleepTime = self.lightSleepTime
                    state.remSleepTime = self.remSleepTime
                    self.sleepState = state

                }
            }
        }
    }

    func getSleepTimeInterval(sleeps: [Sleep]) -> TimeInterval {
        var result: TimeInterval = 0
        
        for sleep in sleeps {
            result += sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate

        }
        return result
    }
    
    func getAwakeDuration(sleeps: [Sleep]) -> TimeInterval {
        var result: TimeInterval = 0
        
        for (index, sleep) in sleeps.enumerated() {
            if index != 0 {
                result += sleep.startDate.timeIntervalSinceReferenceDate - sleeps[index - 1].endDate.timeIntervalSinceReferenceDate
            }
        }
        return result
    }
    
    func getHourLabels(startSleep: Date, endSleep: Date) -> [HourItem] {
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
    
    func getSleepPoints(sleeps: [Sleep], sleepDuration: Double, heartRateAverage: Double) -> [SleepPoint] {
        var sleepPoints: [SleepPoint] = []
        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)
        for sleep in sleeps {
            // when awake
            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && sleepDuration != 0){
                sleepPoints = setSleepPoint(startValue: lastEndTime.timeIntervalSinceReferenceDate,
                                            endValue: sleep.startDate.timeIntervalSinceReferenceDate,
                                            sleepType: SleepType.Awake,
                                            sleepPoints: sleepPoints,
                                            sleepDuration: sleepDuration)
            }
            var startValue = sleep.startDate
            
            if sleep.heartRates.count > 2 {
                for heartRate in sleep.heartRates {
                    let sleepType: SleepType = getSleepType(heartRate: heartRate, heartRateAverage: heartRateAverage)
                    let endValue = heartRate.startDate
                    setSleepTypeTime(sleepType: sleepType, start: startValue, end: endValue)
                    
                    sleepPoints = setSleepPoint(startValue: startValue.timeIntervalSinceReferenceDate,
                                                endValue: endValue.timeIntervalSinceReferenceDate,
                                                sleepType: sleepType,
                                                sleepPoints: sleepPoints,
                                                sleepDuration: sleepDuration)
                    
                    startValue = heartRate.startDate
                }
                setSleepTypeTime(sleepType: SleepType.LightSleep, start: startValue, end: sleep.endDate)

                sleepPoints = setSleepPoint(startValue: startValue.timeIntervalSinceReferenceDate,
                                            endValue: sleep.endDate.timeIntervalSinceReferenceDate,
                                            sleepType: SleepType.LightSleep,
                                            sleepPoints: sleepPoints,
                                            sleepDuration: sleepDuration)
            } else {
                setSleepTypeTime(sleepType: SleepType.LightSleep, start: sleep.startDate, end: sleep.endDate)

                sleepPoints = setSleepPoint(startValue: sleep.startDate.timeIntervalSinceReferenceDate,
                                            endValue: sleep.endDate.timeIntervalSinceReferenceDate,
                                            sleepType: SleepType.LightSleep,
                                            sleepPoints: sleepPoints,
                                            sleepDuration: sleepDuration)
            }
            lastEndTime = sleep.endDate
        }
        
        return sleepPoints
    }
    
    func addTimeToInterval(_ sleeptime: inout TimeInterval, _ start: Date, _ end: Date) {
        let duration = end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
        sleeptime += duration
    }
    
    func setSleepTypeTime(sleepType: SleepType, start: Date, end: Date) {
        switch sleepType {
        case .DeepSleep:
//            self.deepSleepTime!
            addTimeToInterval(&self.deepSleepTime!, start, end)
        case .LightSleep:
            addTimeToInterval(&self.lightSleepTime!, start, end)
        case .RemSleep:
            addTimeToInterval(&self.remSleepTime!, start, end)
        default:
            break
        }
        
    }
    
    func getSleepType(heartRate: HeartRate, heartRateAverage: Double) -> SleepType {
        var sleepType: SleepType
        
        if heartRate.value < heartRateAverage - ((3/100) * heartRateAverage) {
            sleepType = SleepType.DeepSleep
        } else if heartRate.value > heartRateAverage + ((8/100) * heartRateAverage) {
            sleepType = SleepType.RemSleep
        } else {
            sleepType = SleepType.LightSleep
        }

        return sleepType
    }
    
    func setSleepPoint(startValue: Double,
                       endValue: Double,
                       sleepType: SleepType,
                       sleepPoints: [SleepPoint],
                       sleepDuration: Double) -> [SleepPoint] {
        var sleepPoints = sleepPoints
        var offsetX = sleepPoints.last?.offsetX ?? 0
                
        let startPoint = SleepPoint(
            type: sleepType.rawValue,
            offsetX: offsetX)
        sleepPoints.append(startPoint)

        let sleepPercent = ((endValue - startValue) / sleepDuration )
        let offset = (sleepPercent) * screenWidth!
        offsetX += offset

        let endPoint = SleepPoint(
            type: sleepType.rawValue,
            offsetX: offsetX)
        sleepPoints.append(endPoint)
        return sleepPoints
    }
    
    func getHeartRateAverage(sleeps: [Sleep]) -> Double {
        var totalHr: [Int] = []
            for sleep in sleeps {
                let intHrs: [Int] = sleep.heartRates.map { Int($0.value) }
                totalHr.append(contentsOf: intHrs )
            }
        return totalHr.count > 0 ? Double(totalHr.reduce(0, +) / totalHr.count) : 0
    }
    
    func calculateMinAndMaxSleepTime(sleeps: [Sleep]) -> (startSleep: Date, endSleep: Date, sleepDuration: TimeInterval, totalTime: TimeInterval) {
        
        let endSleep: Date = sleeps.max(by: { $0.endDate < $1.endDate }).map( { $0.endDate} )!
        let startSleep = sleeps.min(by: { $0.startDate < $1.startDate }).map( { $0.startDate } )!
        let sleepDuration: TimeInterval = (endSleep.timeIntervalSinceReferenceDate ) - (startSleep.timeIntervalSinceReferenceDate )
        let totalTime = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate

        return (startSleep, endSleep, sleepDuration, totalTime)
    }
}
