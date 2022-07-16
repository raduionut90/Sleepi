//
//  Activity.swift
//  Sleepi
//
//  Created by Ionut Radu on 03.07.2022.
//

import Foundation

class Activity {
    let startDate: Date
    let endDate: Date
    var hr: Double?
    var actEng: Double?
    
    init(startDate: Date, endDate: Date, hr: Double){
        self.startDate = startDate
        self.endDate = endDate
        self.hr = hr
    }
    
    init(startDate: Date, endDate: Date, actEng: Double){
        self.startDate = startDate
        self.endDate = endDate
        self.actEng = actEng
    }
    
    func getSleepType(_ heartRateAverage: Double) -> SleepType {
        var result: SleepType = SleepType.LightSleep
        
//        if let hr = self.hr {
//            if hr <= heartRateAverage - 5 {
//                result = SleepType.DeepSleep
//            } else if hr > heartRateAverage + 8 {
//                result = SleepType.RemSleep
//            } else {
//                result = SleepType.LightSleep
//            }
//        }

        if let activeEnergy = self.actEng {
            if activeEnergy < 0.06 {
                result = SleepType.DeepSleep
            } else if activeEnergy > 0.4 {
                result = SleepType.RemSleep
            } else {
                result = SleepType.LightSleep
            }
        }

        return result
    }
}
