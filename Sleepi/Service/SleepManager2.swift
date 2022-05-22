////
////  SleepManager.swift
////  Sleepi
////
////  Created by Ionut Radu on 18.05.2022.
////
//
//import HealthKit
//import SwiftUI
//
//class SleepManager2 {
//    private var healthStore: HealthStore?
//    var currentDate: Date = Date()
//    var sleeps: [Sleep]
//    var startSleep: Date = Date.init(timeIntervalSince1970: 0)
//    var endSleep: Date = Date.init(timeIntervalSince1970: 0)
//    var timeDiff: Double = 0
//    private var heartRates: [HeartRate] = [HeartRate]()
//
//    init(){
//        self.sleeps = loadSleeps()
//        if HKHealthStore.isHealthDataAvailable() {
//            healthStore = HealthStore()
//        }
//    }
//
////    func changeDate(date: Date) {
////        currentDate = date
////        print("Date changed: \(date)")
////        print("Date changed: \(currentDate)")
////    }
//    
//
//    func getHourLabels() -> [String] {
//        var hours: [Int] = []
//        let startHour = Calendar.current.component(.hour, from: startSleep)
//        let endHour = Calendar.current.component(.hour, from: endSleep)
//
//        if (startHour > endHour) {
//            for h in startHour ... 24 {
//                if h == 24{
//                    hours.append(0)
//                } else {
//                    hours.append(h)
//
//                }
//            }
//            for h in 1 ... endHour {
//                hours.append(h)
//            }
//        } else {
//            for h in startHour ... endHour {
//                hours.append(h)
//            }
//        }
//        return hours.map { String($0) }
//    }
//    
//    func getSleepPoints() -> [SleepPoint] {
//
//        var sleepPoints = [SleepPoint]()
//        let screenWidth = UIScreen.main.bounds.width - 30
//        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)
//        
//        print("Sleeps.count: " + "\(sleeps.count)")
//        
//        if (sleeps.count == 0 || timeDiff == 0) {
//            return []
//        }
//
//        var offsetX: Double = 0
//        for sleep in sleeps {
//            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && timeDiff != 0){
//                let sleepType = (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 10 * 60 ?
//                SleepType.RemSleep.rawValue : SleepType.Awake.rawValue
//                
//                print("type: \((sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 160)")
//                print("type: \((lastEndTime.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) )")
//
//                let startPoint = SleepPoint(
//                    type: sleepType,
//                    offsetX: offsetX)
//                sleepPoints.append(startPoint)
//
//                let sleepPercent: Double = ( (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) / timeDiff )
//                let offset = (sleepPercent) * screenWidth
//                offsetX += offset
//
//                let endPoint = SleepPoint(
//                    type: sleepType,
//                    offsetX: offsetX)
//                sleepPoints.append(endPoint)
//
//            }
//
//            let startPoint = SleepPoint(
//                type: SleepType.LightSleep.rawValue,
//                offsetX: offsetX)
//            sleepPoints.append(startPoint)
//
//            let sleepPercent = ((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) / timeDiff )
//            let offset = (sleepPercent) * screenWidth
//            offsetX += offset
//
//            let endPoint = SleepPoint(
//                type: SleepType.LightSleep.rawValue,
//                offsetX: offsetX)
//            sleepPoints.append(endPoint)
//
//            lastEndTime = sleep.endDate
//        }
//
//        return sleepPoints
//    }
//    
//   
//    
//    func getSleptTime() -> DateComponents {
//        let difference = Calendar.current.dateComponents([.hour, .minute], from: startSleep, to: endSleep)
//        return difference
//    }
//    
//    private func calculateMinAndMaxSleepTime() {
//        if let earliest = sleeps.min(by: { $0.startDate < $1.startDate }) {
//            // use earliest reminder
//            startSleep = earliest.startDate
//        }
//        if let latest = sleeps.max(by: { $0.endDate < $1.endDate }) {
//            // use earliest reminder
//            endSleep = latest.endDate
//        }
//        timeDiff = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
//    }
//}
