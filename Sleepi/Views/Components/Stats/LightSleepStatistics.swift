//
//  LightSleepStatistics.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct LightSleepStatistics: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        HStack {
            let percent = sleepManager.getSleepStageDuration(stage: .LightSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
            Circle()
                .fill(Color(UIColor(named: "AppLightSleep")!))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                
                Text("Light ")
                Text("Reference: 40-60%")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            Spacer()
            VStack {
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .LightSleep))!)
                Text("\(String(format: "%.0f", percent)) %")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            
        }
    }
} 
