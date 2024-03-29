//
//  Activity.swift
//  Sleepi
//
//  Created by Ionut Radu on 03.07.2022.
//

import Foundation
 
class Record: Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    internal init(startDate: Date, endDate: Date, hr: Double? = nil, actEng: Double? = nil, hrv: Double? = nil, rhr: Double? = nil, respRate: Double? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.hr = hr
        self.actEng = actEng
        self.hrv = hrv
        self.rhr = rhr
        self.respRate = respRate
    }
    
    static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let startDate: Date
    let endDate: Date
    var hr: Double?
    var actEng: Double?
    var hrv: Double?
    var rhr: Double?
    var respRate: Double?
    var charging: Bool = false
    var walking: Bool = false
}
