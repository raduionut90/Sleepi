//
//  Activity.swift
//  Sleepi
//
//  Created by Ionut Radu on 03.07.2022.
//

import Foundation

class Activity {
    let date: Date
    var hr: Double?
    var actEng: Double?
    
    init(date: Date, hr: Double){
        self.date = date
        self.hr = hr
    }
    
    init(date: Date, actEng: Double){
        self.date = date
        self.actEng = actEng
    }
}
