//
//  NapStatistics.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct NapStatistics: View {
    @ObservedObject var sleepManager: SleepManager

    var body: some View {
        ForEach(sleepManager.naps) { nap in
            HStack {
                Circle()
                    .fill(Color(UIColor(named: "BackgroundSec")!))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading) {
                    Text("Nap")
                    Text(Utils.hhmmtimeFormatter.string(from: nap.startDate) + " - " +  Utils.hhmmtimeFormatter.string(from: nap.endDate))
                        .font(.caption2)
                        .foregroundColor(Color("TextColorSec"))
                }
                Spacer()
                Text(Utils.timeForrmatedAbr.string(from: nap.getDuration() )!)
            }
        }
    }
}
