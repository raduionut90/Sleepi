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
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
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
        
        let filteredValues = values.filter {!$0.isNaN}.filter {$0 != 0}
        if filteredValues.count < 3 {
            return (0.0, 0.0, 0.0)
        }
        let dif = filteredValues.max()! - filteredValues.min()!
        let q1 = 0.20 * dif + filteredValues.min()!
        let med = 0.40 * dif + filteredValues.min()!
        let q3 = 0.7 * dif + filteredValues.min()!
        
        return (q1, med, q3);
    }
    
    static func getEpochs(activities: [Record]) -> [Epoch]{
        var epochs: [Epoch] = []
        
        if activities.isEmpty {
            return epochs
        }
        
        let hrActivities = activities.filter { $0.hr != nil }
        if hrActivities.isEmpty {
            for (index, activity) in activities.enumerated() {
                let startDate: Date = activities.indices.contains(index - 1) ? activities[index - 1].startDate : activities.first!.startDate
                
                let epoch = Epoch(start: startDate,
                                  end: activity.startDate,
                                  records: activities.filter( { (index == 0 ? $0.startDate >= startDate : $0.startDate > startDate) && $0.startDate <= activity.startDate } ),
                                  stage: nil)
                epochs.append(epoch)
            }
        }
        for (index, activity) in hrActivities.enumerated() {
            let startDate: Date = hrActivities.indices.contains(index - 1) ? hrActivities[index - 1].startDate : activities.first!.startDate
            
            let epoch = Epoch(start: startDate,
                              end: activity.startDate,
                              records: activities.filter( { (index == 0 ? $0.startDate >= startDate : $0.startDate > startDate) && $0.startDate <= activity.startDate } ),
                              stage: nil)
            epochs.append(epoch)
        }
        
        return epochs
    }
    
    static func getActivitiesFromRawData(
        heartRates: [HKQuantitySample],
        activeEnergy: [HKQuantitySample]) -> [Record] {
            
            var allRecords: [Record] = []
            var allHr: [Record] = []
            var allActiveEnergies: [Record] = []
            
            for actEnergy in activeEnergy {
                let record = Record(startDate: actEnergy.startDate, endDate: actEnergy.endDate, actEng: actEnergy.quantity.doubleValue(for: .kilocalorie()))
                allActiveEnergies.append(record)
            }
            
            for heartRate in heartRates {
                let record = Record(startDate: heartRate.startDate, endDate: heartRate.endDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
                allHr.append(record)
            }
            
            //        Utils.processActivities(&allActiveEnergies)
            allRecords.append(contentsOf: allActiveEnergies)
            allRecords.append(contentsOf: allHr)
            allRecords = allRecords.sorted { a,b in
                a.startDate < b.startDate
            }
            
            return allRecords
        }
    
    static func isNap(_ sleep: Sleep) {
        
    }
}
