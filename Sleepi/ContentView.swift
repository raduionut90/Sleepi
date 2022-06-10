//
//  ContentView.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var currentDate: Date = Date()
    @StateObject var sleepManager: SleepManager = SleepManager(date: Date(), screenWidth: UIScreen.main.bounds.width - 30)

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
    
    
    private var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, dd MMM yyyy, HH:mm"
        return formatter
    }()

    
    private var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    var body: some View {
//        if sleepManager.sleepState != nil {
        NavigationView{
            VStack {
                HStack{
                    Spacer()
                    Button(action: {
                        addingDays(nr: -1)
                    }) {
                        Text("<")
                            .font(.title)
                    }
                    Text(dateFormatter.string(from: currentDate))
                        .font(.title)
                    if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                        Button(action: {
                            addingDays(nr: 1)
                        }) {
                            Text(">")
                                .font(.title)
                        }
                    }
                    Spacer()
                }.padding()
                Text("Night Sleep")

                if sleepManager.sleepState != nil {
                    Text(timeFormatter.string(from: sleepManager.sleepState!.totalBedTime )! )
                }
                
                if sleepManager.sleepState != nil {

                VStack{
                    LineChartView(speed: (sleepManager.sleepState?.startSleep.timeIntervalSince1970)!,
                                  sleepPoints: (sleepManager.sleepState?.sleepPoints)!,
                                  labels: (sleepManager.sleepState?.hoursLabels)!,
                                  startSleep: (sleepManager.sleepState?.startSleep)!,
                                  endSleep: (sleepManager.sleepState?.endSleep)! )
                }.padding()
                }

                VStack {
                    Text("Scoring: 80")
                    HStack {
                        Text("Night sleep: ")
                        Text(timeFormatter.string(from: sleepManager.sleepState?.sleepTime ?? 0)! )

                    }
                    HStack {
                        Text("Deep sleep:")
                        Text(timeFormatter.string(from: sleepManager.sleepState?.deepSleepTime ?? 0)! )
                    }
                    HStack {
                        Text("Light sleep:")
                        Text(timeFormatter.string(from: sleepManager.sleepState?.lightSleepTime ?? 0)! )
                    }
                    HStack {
                        Text("REM sleep:")
                        Text(timeFormatter.string(from: sleepManager.sleepState?.remSleepTime ?? 0)! )
                    }
                    Text("Deep Sleep continuity:")
                    HStack {
                        Text("Awake times:")
                        let awake = sleepManager.sleepState?.sleeps.count ?? 0
                        Text(String(awake > 0 ? awake - 1 : awake))
                    }
                    HStack{
                        Text("Awake:")
//                        let awakeTime = sleepManager.sleepState?.awakeTime ?? DateComponents()
                        Text(timeFormatter.string(from: sleepManager.sleepState?.awakeTime ?? 0)! )
                    }
                    Text("Breathing quality:")
                }
                Spacer()

//                if sleepManager.sleepState != nil {
//                    List((sleepManager.sleepState?.sleeps)! , id: \.id) { sleep in
//                        VStack(alignment: .leading){
//                            Text("\(sleep.value)")
//                            Text(sleep.startDate,  formatter: formatter).opacity(0.5)
//                            Text(sleep.endDate, formatter: formatter).opacity(0.5)
//                            Text(sleep.source)
//                            Text("\(sleep.heartRates.count)")
//                        }
//                    }
//                }
            }
            .navigationTitle("Sleepi")
        }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear(){
//                MotionService().startDeviceMotion()
                MotionService().readMotionData()
                sleepManager.refreshSleeps(date: currentDate)
            }
            .onChange(of: currentDate, perform: { value in
                sleepManager.refreshSleeps(date: value)
                MotionService().readMotionData()
            })
        }

    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portrait)
    }
}
