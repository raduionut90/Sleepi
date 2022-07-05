//
//  ContentView.swift
//  Sleepi Watch WatchKit Extension
//
//  Created by Ionut Radu on 01.06.2022.
//

import SwiftUI
import CoreMotion

struct ContentView: View {
    @State private var currentDate: Date = Date()
    @StateObject var sleepManager: SleepManager = SleepManager(date: Date())
    var swipeGestureRecognizer = WKSwipeGestureRecognizer()

    private var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    func addingDays(nr: Int) -> Void {
        var dateComponent = DateComponents()
        dateComponent.day = nr
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        self.currentDate = futureDate!
    }
    
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack{
            HStack{
                Spacer()
                Text(dateFormatter.string(from: currentDate))
                    .font(.headline)
                Spacer()
            }.padding()
            HStack {
                Text("Night sleep: ")
                Text(timeFormatter.string(from: sleepManager.sleepState?.sleepTime ?? 0)! )

            }
        }
        .onAppear(){
            sleepManager.refreshSleeps(date: currentDate)
        }
        .onChange(of: currentDate, perform: { value in
            sleepManager.refreshSleeps(date: value)
        })
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onEnded({ value in
                                if value.translation.width < 0 {
                                    if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                                        addingDays(nr: 1)
                                    }
                                }
                                if value.translation.width > 0 {
                                    // left
                                    addingDays(nr: -1)
                                }
//                                if value.translation.height < 0 {
//                                    // up
//                                }
//
//                                if value.translation.height > 0 {
//                                    // down
//                                }
                            }))    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
