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
        NavigationView{
                VStack {
                    VStack {
                    // Date Component View
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
                            
                            HStack() {
                                VStack {
                                    Text("In Bed")
                                        .font(.subheadline)
                                        .fontWeight(.light)
                                        
                                    Text(Utils.timeFormatter.string(from: sleepManager.getInBedTime() )! )
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                VStack {
                                    Text("Night Sleep")
                                        .font(.subheadline)
                                        .fontWeight(.light)
                                        
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepDuration(type: .NightSleep) )! )
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                VStack {
                                    Text("Nap")
                                        .font(.subheadline)
                                        .fontWeight(.light)
                                        
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepDuration(type: .Nap) )! )
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                VStack {
                                    Text("Total")
                                        .font(.subheadline)
                                        .fontWeight(.light)
                                        
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepDuration(type: .All) )! )
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding()
                        }
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
                        
            
                        VStack {
                            LineChartView(sleeps: sleepManager.nightSleeps, timeInBed: sleepManager.getInBedTime(), sleepsHrAverage: sleepManager.nsHeartRateAverage)
         
                            // FOR NAPS
    //                        ForEach(sleepManager.naps) { nap in
    //                            Text("NAPS")
    //                            LineChartView(sleeps: [nap], timeInBed: (nap.endDate.timeIntervalSinceReferenceDate - nap.startDate.timeIntervalSinceReferenceDate), sleepsHrAverage: sleepManager.nsHeartRateAverage)
    //                        }
                        }
                        .padding(.all, 15)
                    }
                    .background(.white)
                    
                    ScrollView(.vertical){

                        VStack {
                            Group {
                                HStack {
                                    Circle()
                                        .fill(Color(UIColor(named: "AppAwakeSleep")!))
                                        .frame(width: 10, height: 10)
                                    Text("Awake")
                                    Spacer()
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepStageDuration(stage: .Awake))!)
                                    
                                }
                                HStack {
                                    Circle()
                                        .fill(Color(UIColor(named: "AppRemSleep")!))
                                        .frame(width: 10, height: 10)
                                    Text("Rem")
                                    Spacer()
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepStageDuration(stage: .RemSleep))!)
                                }
                                HStack {
                                    Circle()
                                        .fill(Color(UIColor(named: "AppLightSleep")!))
                                        .frame(width: 10, height: 10)
                                    Text("Light")
                                    Spacer()
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepStageDuration(stage: .LightSleep))!)
                                    
                                }
                                HStack {
                                    Circle()
                                        .fill(Color(UIColor(named: "AppDeepSleep")!))
                                        .frame(width: 10, height: 10)
                                    Text("Deep")
                                    Spacer()
                                    Text(Utils.timeFormatter.string(from: sleepManager.getSleepStageDuration(stage: .DeepSleep))!)
                                }
                                ForEach(sleepManager.naps) { nap in
                                    HStack {
                                        Text("Nap")
                                        Spacer()
                                        Text(Utils.timeFormatter.string(from: nap.getDuration() )!)
                                    }
                                }
                            }
                            .padding()
                            .background(/*@START_MENU_TOKEN@*//*@PLACEHOLDER=View@*/Color.white/*@END_MENU_TOKEN@*/)
                            .cornerRadius(10)
                        }
                        .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
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
                .navigationTitle("Sleepi")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color("Background"))

        }
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
            .onChange(of: sleepManager.nightSleeps, perform: { value in
                let deep = sleepManager.getSleepStageDuration(stage: .DeepSleep)
                print("deep: \(Utils.timeFormatter.string(from: deep)!)")
                let rem = sleepManager.getSleepStageDuration(stage: .RemSleep)
                print("rem: \(Utils.timeFormatter.string(from: rem)!)")
                let light = sleepManager.getSleepStageDuration(stage: .LightSleep)
                print("light: \(Utils.timeFormatter.string(from: light)!)")
                print("total: \(Utils.timeFormatter.string(from: deep + rem + light)!)")

            })
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
        ContentView()
            .previewInterfaceOrientation(.portraitUpsideDown)
    }
}
