//
//  AwakeStatistics.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct AwakeStatistics: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        HStack {
            let times = sleepManager.nightSleeps.filter( {$0.stage == .Awake}).count
            Circle()
                .fill(Color(UIColor(named: "AppAwakeSleep")!))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text("Awake")
                Text("Reference: 1 time")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
            Spacer()
            VStack {
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .Awake))!)
                Text("\(String(times)) times")
                    .font(.caption2)
                    .foregroundColor(Color("TextColorSec"))
            }
        }
    }
}
