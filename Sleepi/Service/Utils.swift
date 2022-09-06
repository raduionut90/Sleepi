//
//  Utils.swift
//  Sleepi
//
//  Created by Ionut Radu on 05.07.2022.
//

import Foundation
import HealthKit

class Utils {
    
    static var dateTimeformatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, dd MMM yyyy, HH:mm"
        return formatter
    }()
    
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    static var hhmmtimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    static var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    static var timeForrmatedAbr: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    static func getAverage(values: [Double]) -> Double {
        return values.filter({!$0.isNaN}).reduce(0, +) / Double(values.filter({!$0.isNaN}).count);
    }
    
    static func getQuartiles(values: [Double]) -> (firstQuartile: Double, median: Double, thirdQuartile: Double) {
        var result: [Double] = [];

        let sortedValues = values.filter({ !$0.isNaN }).sorted(by: <)
        if sortedValues.count < 3 {
            return (0.0, 0.0, 0.0)
        }
        for quartileType in 1...3 {
            let length = sortedValues.count + 1
            let quartileSize: Double = (Double(length) * (Double(quartileType) * 25.0 / 100.0)) - 1.0
            if quartileSize.truncatingRemainder(dividingBy: 1) == 0 {
                result.append(sortedValues[Int(quartileSize)])
            } else {
                result.append((sortedValues[Int(quartileSize)] + sortedValues[Int(quartileSize) + 1]) / 2)
            }
        }
        return (result[0], result[1], result[2]);
    }
    
    static func getEpochs(activities: [Records], minutes: Int) -> [Epoch]{
        var epochs: [Epoch] = []
        var firstIndex = 0
        while firstIndex <= activities.indices.last! {
            let startEpoch: Date = activities[firstIndex].startDate
            let endPeriod = Calendar.current.date(byAdding: .minute, value: minutes, to: startEpoch)!
            let lastIndex = activities.lastIndex(where: {$0.startDate < endPeriod} )!
            let endEpoch = activities[lastIndex].endDate
            let epoch: Epoch = Epoch(start: startEpoch, end: endEpoch, records: Array(activities[firstIndex...lastIndex]))
            epochs.append(epoch)
            firstIndex = lastIndex + 1
        }

        return epochs
    }
    
    
    static func getEpochsFromActivitiesByTimeInterval(start: Date, end: Date, activities: [Records], minutes: Int) -> [Epoch]{
        var epochs: [Epoch] = []
        var firstIndex = 0
        while firstIndex <= activities.indices.last! {
            let startEpoch: Date = firstIndex == 0 ? start : activities[firstIndex].startDate
            let endPeriod = Calendar.current.date(byAdding: .minute, value: minutes, to: startEpoch)!
            let lastIndex = activities.lastIndex(where: {$0.startDate < endPeriod} )!
            let endEpoch = activities.indices.contains(lastIndex + 1) ? activities[lastIndex + 1].startDate : end
            let epoch: Epoch = Epoch(start: startEpoch, end: endEpoch, records: Array(activities[firstIndex...lastIndex]))
            epochs.append(epoch)
//            if lastIndex == activities.indices.last {
//                break
//            }
            firstIndex = lastIndex + 1
        }
//        let recordsCount = epochs.flatMap({$0.records})
//        if recordsCount.count != activities.count {
//            print("ERROR-COUNTER \(epochs.map {$0.records}.count) - \(activities.count)")
//        }
//        if end != activities.last?.endDate {
//            print("")
//        }
        return epochs
    }
    
    static func getActivitiesFromRawData(
            heartRates: [HKQuantitySample],
            activeEnergy: [HKQuantitySample]
    ) -> [Records] {
        var allRecords: [Records] = []
        var allHr: [Records] = []
        var allActiveEnergies: [Records] = []

        for actEnergy in activeEnergy {
            let record = Records(startDate: actEnergy.startDate, endDate: actEnergy.endDate, actEng: actEnergy.quantity.doubleValue(for: .kilocalorie()))
            allActiveEnergies.append(record)
        }
        
        for heartRate in heartRates {
            let record = Records(startDate: heartRate.startDate, endDate: heartRate.endDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
                allHr.append(record)
        }
        
//        Utils.processActivities(&allActiveEnergies)
        allRecords.append(contentsOf: allActiveEnergies)
        allRecords.append(contentsOf: allHr)
        allRecords = allRecords.sorted { a,b in
            a.startDate < b.startDate
        }
        for (index, record) in allRecords.enumerated() {
            if index - 1 > 0 && record.startDate.timeIntervalSinceReferenceDate - allRecords[index - 1].endDate.timeIntervalSinceReferenceDate > 600 {
                record.firstAfterGap = true
            }
        }
        
        return allRecords
    }
    
    static func processActivities(_ activities: inout [Records]) {
        for (index, activity) in activities.filter({$0.actEng != 0}).enumerated() {
            var prev1: Double = 0.0
            var prev2: Double = 0.0
            var next1: Double = 0.0
            var next2: Double = 0.0
            
            if index - 2 >= 0 {
                prev2 = (activities[index - 2].actEng ?? 0) * (1/25)
            }
            if index - 1 >= 0 {
                prev1 = (activities[index - 1].actEng ?? 0) * (1/5)
            }
            let current = activity.actEng ?? 0
            if index + 1 < activities.count {
                next1 = (activities[index + 1].actEng ?? 0) * (1/5)
            }
            if index + 2 < activities.count {
                next2 = (activities[index + 2].actEng ?? 0) * (1/25)
            }
            
            let sum = prev2 + prev1 + current + next1 + next2
            activity.actEng = sum
//            print("\(activity.startDate.formatted());"
//                  + "\(activity.hr ?? 0);"
//                  + "\(sum);"
//            )
        }
    }
}
