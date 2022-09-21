//
//  HeartRatesChart.swift
//  Sleepi
//
//  Created by Ionut Radu on 21.09.2022.
//

import SwiftUI

struct HeartRatesChart: Shape {
    let records: [Record]
    let chartWidth: Double
    let timeInBed: Double
    func path(in rect: CGRect) -> Path {
        var offsetX: Double = 0
        return Path { path in
            path.move(to: CGPoint(x: offsetX, y: records.first!.hr!))
            
            for (index, record) in records.enumerated() {
                var interval: Double = 0
                if records.indices.contains(index - 1) {
                    interval = record.startDate.timeIntervalSinceReferenceDate - records[index - 1].startDate.timeIntervalSinceReferenceDate
                }
                offsetX += interval > 0 ? interval / timeInBed * chartWidth : 0
                path.addLine(to: CGPoint(x: offsetX, y: record.hr! * 5 - 250 ))
            }
        }
    }
}

struct HeartRatesChart_Previews: PreviewProvider {
    static var previews: some View {
        HeartRatesChart(records: [
            Record(startDate: Date(), endDate: Date())
        ],
        chartWidth: 314,
        timeInBed: 1000000.0)
        .stroke(.red, lineWidth: 2)
    }
}
