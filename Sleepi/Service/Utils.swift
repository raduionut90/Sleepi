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
    
    static func getActivitiesFromRawData(_ heartRates: [HKQuantitySample], _ activeEnergy: [HKQuantitySample]) -> [Activity] {
        var activities: [Activity] = []

        for actEnergy in activeEnergy {
            let record = Activity(startDate: actEnergy.startDate, endDate: actEnergy.endDate, actEng: actEnergy.quantity.doubleValue(for: .kilocalorie()))
            activities.append(record)
        }
        
        for heartRate in heartRates {
            if let existingRecord = activities.first(where: {Utils.dateTimeformatter.string(from: $0.startDate) ==
                                                Utils.dateTimeformatter.string(from: heartRate.startDate)} ) {
                existingRecord.hr = heartRate.quantity.doubleValue(for: HKUnit(from: "count/min"))
            } else {
                let record = Activity(startDate: heartRate.startDate, endDate: heartRate.endDate, hr: heartRate.quantity.doubleValue(for: HKUnit(from: "count/min")))
                activities.append(record)
            }

        }
        activities = activities.sorted { a,b in
            a.startDate < b.startDate
        }
        
//      used for debug
//        for record in activities {
//            print("\(record.startDate.formatted());\(record.hr ?? 999);\(record.actEng ?? 999)")
//        }
        
        return activities
    }
}
