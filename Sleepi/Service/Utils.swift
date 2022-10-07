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
    
    static func getEpochs(activities: [Record], minutes: Int) -> [Epoch]{
        var epochs: [Epoch] = []
        var firstIndex = 0
        if activities.isEmpty {
            return epochs
        }
        while firstIndex <= activities.indices.last! {
            let startEpoch: Date = activities[firstIndex].startDate
            let endPeriod = Calendar.current.date(byAdding: .minute, value: minutes, to: startEpoch)!
            let lastIndex = activities.lastIndex(where: {$0.startDate < endPeriod} )!
            let endEpoch = activities[lastIndex].endDate
            let epoch: Epoch = Epoch(start: startEpoch, end: endEpoch, records: Array(activities[firstIndex...lastIndex]), stage: nil)
            epochs.append(epoch)
            firstIndex = lastIndex + 1
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
    
}
