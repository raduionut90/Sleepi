//
//  ContentView.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State var currentDate: Date = Date()
    @StateObject var sleepManager: SleepManager = SleepManager(date: Date())
    @StateObject var sleepDetector: SleepDetector = SleepDetector()
    
    func addingDays(nr: Int) -> Void {
        var dateComponent = DateComponents()
        dateComponent.day = nr
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        self.currentDate = futureDate!
    }
    
    var body: some View {
//        NavigationView{
        ScrollView(.vertical){

                VStack {

                    VStack {
                    // Date Component View
                        Group {
                            VStack {
                                HStack{
                                    Button(action: {
                                        addingDays(nr: -1)
                                    }) {
                                        Text("<")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    Text(Utils.dateFormatter.string(from: currentDate))
                                        .font(.title3)
                                    Spacer()

                                    if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                                        Button(action: {
                                            addingDays(nr: 1)
                                        }) {
                                            Text(">")
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .gesture(DragGesture(minimumDistance: 70.0, coordinateSpace: .local)
                                    .onEnded { value in
                    
                                        if value.translation.width < 0 {
                                            if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                                                    addingDays(nr: 1)
                                            }
                                        } else {
                                            addingDays(nr: -1)
                                        }
                                    }
                                )
                            }
                        
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
//                                VStack {
//                                    Text("Night Sleep")
//                                        .font(.subheadline)
//                                        .fontWeight(.light)
//
//                                    Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepDuration(type: .NightSleep) )! )
//                                        .font(.title2)
//                                        .fontWeight(.medium)
//                                }
//                                Spacer()
                                VStack {
                                    Text("Nap")
                                        .font(.subheadline)
                                        .fontWeight(.light)
                                        
                                    Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepDuration(type: .Nap) )! )
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding()

                        
                            VStack {
                                LineChartView(sleeps: sleepManager.nightSleeps, timeInBed: sleepManager.getInBedTime(), sleepsHrAverage: sleepManager.nsHeartRateAverage)
                            }
                            .padding(.all, 15)
                        }
                        .foregroundColor(Color("TextColorPrim"))
                        .background(Color("BackgroundSec"))
                        .cornerRadius(16)
                        
                    }
                    .padding()
//                    .background(Color("BackgroundSec"))
                    if !sleepManager.nightSleeps.isEmpty {
                            VStack {
                                Group {
                                    HStack {
                                        let times = sleepManager.nightSleeps.count - 1
                                        Circle()
                                            .fill(Color(UIColor(named: "AppAwakeSleep")!))
                                            .frame(width: 10, height: 10)
                                        VStack(alignment: .leading) {
                                            Text("Awake \(String(times)) times")
                                            Text("Reference: 1 time")
                                                .font(.caption2)
                                                .foregroundColor(Color("TextColorSec"))
                                        }
                                        Spacer()
                                        Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .Awake))!)
                                    }
                                    HStack {
                                        let percent = sleepManager.getSleepStageDuration(stage: .RemSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
                                        Circle()
                                            .fill(Color(UIColor(named: "AppRemSleep")!))
                                            .frame(width: 10, height: 10)
                                        VStack(alignment: .leading) {
                                            Text("Rem \(String(format: "%.0f", percent)) %")
                                            Text("Reference: 10-30%")
                                                .font(.caption2)
                                                .foregroundColor(Color("TextColorSec"))
                                        }
                                        Spacer()
                                        Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .RemSleep))!)
                                    }
                                    HStack {
                                        let percent = sleepManager.getSleepStageDuration(stage: .LightSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
                                        Circle()
                                            .fill(Color(UIColor(named: "AppLightSleep")!))
                                            .frame(width: 10, height: 10)
                                        VStack(alignment: .leading) {
                                   
                                            Text("Light \(String(format: "%.0f", percent)) %")
                                            Text("Reference: 40-60%")
                                                .font(.caption2)
                                                .foregroundColor(Color("TextColorSec"))
                                        }
                                        Spacer()
                                        Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .LightSleep))!)
                                        
                                    }
                                    HStack {
                                        let percent = sleepManager.getSleepStageDuration(stage: .DeepSleep) / sleepManager.getSleepDuration(type: .NightSleep) * 100
                                        Circle()
                                            .fill(Color(UIColor(named: "AppDeepSleep")!))
                                            .frame(width: 10, height: 10)
                                        VStack(alignment: .leading) {
                                            Text("Deep \(String(format: "%.0f", percent)) %")
                                            Text("Reference: 20-60%")
                                                .font(.caption2)
                                                .foregroundColor(Color("TextColorSec"))
                                        }
                                        Spacer()
                                        Text(Utils.timeForrmatedAbr.string(from: sleepManager.getSleepStageDuration(stage: .DeepSleep))!)

                                    }
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
                                .padding()
                                .background(Color("BackgroundSec"))
                                .foregroundColor(Color("TextColorPrim"))
                                .cornerRadius(16)

                            }
                            .padding(.all)
                            .gesture(DragGesture(minimumDistance: 70.0, coordinateSpace: .local)
                                .onEnded { value in
                                    
                                    if value.translation.width < 0 {
                                        if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                                            addingDays(nr: 1)
                                        }
                                    } else {
                                        addingDays(nr: -1)
                                    }
                                }
                            )
                        }
                    }

                }
//                .navigationTitle("Sleepi")
//                .navigationBarTitleDisplayMode(.inline)
                .background(Color("BackgroundPrim"))
//
//        }
//            .background(.red)
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear(){
                sleepDetector.performSleepDetection()
                sleepManager.refreshSleeps(date: currentDate)
            }
            .onChange(of: currentDate, perform: { value in
                sleepManager.refreshSleeps(date: value)
            })
            .onChange(of: sleepDetector.loading, perform: { _ in
                sleepManager.refreshSleeps(date: currentDate)
            })
//            .onChange(of: sleepManager.nightSleeps, perform: { value in
//                let deep = sleepManager.getSleepStageDuration(stage: .DeepSleep)
//                print("deep: \(Utils.timeFormatter.string(from: deep)!)")
//                let rem = sleepManager.getSleepStageDuration(stage: .RemSleep)
//                print("rem: \(Utils.timeFormatter.string(from: rem)!)")
//                let light = sleepManager.getSleepStageDuration(stage: .LightSleep)
//                print("light: \(Utils.timeFormatter.string(from: light)!)")
//                print("total: \(Utils.timeFormatter.string(from: deep + rem + light)!)")
//
//            })
//            .gesture(DragGesture(minimumDistance: 70.0, coordinateSpace: .local)
//                .onEnded { value in
//
//                    if value.translation.width < 0 {
//                        if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
//                                addingDays(nr: 1)
//                        }
//                    } else {
//                        addingDays(nr: -1)
//                    }
//                }
//            )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewInterfaceOrientation(.portrait)
            ContentView()
                .previewInterfaceOrientation(.landscapeLeft)
            ContentView()
                .previewInterfaceOrientation(.portraitUpsideDown)
                .preferredColorScheme(.dark)
            ContentView()
                .previewInterfaceOrientation(.landscapeLeft)
                .preferredColorScheme(.dark)
        }
    }
}
