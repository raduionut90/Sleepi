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
    
    static func getAverage(array: [Activity], by: HKQuantityTypeIdentifier) -> Double {
        if by == .heartRate {
            let sumResultHr = array.compactMap(\.hr).reduce(0.0, +)
            return (sumResultHr / Double(array.compactMap(\.hr).count))
        } else if by == .activeEnergyBurned {
            let sumResultHr = array.compactMap(\.actEng).reduce(0.0, +)
            return (sumResultHr / Double(array.compactMap(\.actEng).count))
        }
        return 0.0;
    }
}
