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
        return values.reduce(0, +) / Double(values.count);
    }
    
    static func getQuartiles(values: [Double]) -> (firstQuartile: Double, median: Double, thirdQuartile: Double) {
        var result: [Double] = [];
        if values.count < 3 {
            return (0.0, 0.0, 0.0)
        }
        let sortedValues = values.sorted(by: <)

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
    
    static func getEpochsFromActivities(activities: [Records]) -> [Epoch]{
        var epochs: [Epoch] = []
        var counter = 0
        while counter  < activities.count {
            let offset = counter + 5 > activities.count - 1 ? activities.count : counter + 5
            let epoch: Epoch = Epoch(activities: Array(activities[counter..<offset]))
            epochs.append(epoch)
            counter += 5
            if counter > activities.count {
                break
            }
        }
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
        
        Utils.processActivities(&allActiveEnergies)
        allRecords.append(contentsOf: allActiveEnergies)
        allRecords.append(contentsOf: allHr)
        allRecords = allRecords.sorted { a,b in
            a.startDate < b.startDate
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
                if activity.startDate.timeIntervalSinceReferenceDate - activities[index - 1].startDate.timeIntervalSinceReferenceDate > 600 {
                    activities[index - 1].firstAfterGap = true
                }
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
