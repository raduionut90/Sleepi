//
//  RemStatistics.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct RemStatistics: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        HStack {
            let percent = sleepManager.getSleepStageDuration(stage: .RemSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
            Circle()
                .fill(Color(UIColor(named: "AppRemSleep")!))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text("Rem")
                Text("Reference: 10-30%")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            Spacer()
            VStack {
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .RemSleep))!)
                Text("\(String(format: "%.0f", percent)) %")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
        }
    }
}
