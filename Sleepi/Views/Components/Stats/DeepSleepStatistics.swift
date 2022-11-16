//
//  DeepSleepStatistics.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct DeepSleepStatistics: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        HStack {
            let percent = sleepManager.getSleepStageDuration(stage: .DeepSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
            Circle()
                .fill(Color(UIColor(named: "AppDeepSleep")!))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text("Deep")
                Text("Reference: 20-60%")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            Spacer()
            VStack {
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .DeepSleep))!)
                Text(" \(String(format: "%.0f", percent)) %")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            
        }
    }
}
