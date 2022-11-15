//
//  DateBar.swift
//  Sleepi
//
//  Created by Ionut Radu on 14.11.2022.
//

import SwiftUI

struct DateBar: View {
    @ObservedObject var sleepManager: SleepManager
    @Binding var currentDate: Date
    @Binding var disableNextDayButton: Bool

    public func addingDays(nr: Int) -> Void {
        var dateComponent = DateComponents()
        dateComponent.day = nr
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        self.currentDate = futureDate!
    }
    
    var body: some View {
        HStack{
            Button(action: {
                addingDays(nr: -1)
            }) {
                Text("<")
                    .font(.title)
                    .foregroundColor(.gray)
            }

            Spacer()
            Text(Utils.dateFormatter.string(from: currentDate))
                .font(.title3)
            Spacer()

            if !disableNextDayButton {
                Button(action: {
                    addingDays(nr: 1)
                }) {
                    Text(">")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
