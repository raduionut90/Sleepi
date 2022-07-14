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
}
