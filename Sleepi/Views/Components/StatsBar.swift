//
//  StatsBar.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct StatsBar: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        HStack() {
            VStack {
                Text("Night Sleep")
                    .font(.subheadline)
                    .fontWeight(.light)
                
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepDuration(type: .NightSleep) )! )
                    .font(.title2)
                    .fontWeight(.medium)
            }
            Spacer()
            VStack {
                Text("Nap")
                    .font(.subheadline)
                    .fontWeight(.light)
                
                Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepDuration(type: .Nap) )! )
                    .font(.title2)
                    .fontWeight(.medium)
            }
        }
    }
}


