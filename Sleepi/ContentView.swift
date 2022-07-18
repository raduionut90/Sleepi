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
                // Date Component View 
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
                }.padding()
                ScrollView(.vertical){

                    HStack() {
                        VStack {
                            Text("In Bed")
                                .font(.title2)
                                .fontWeight(.light)

                            Text(Utils.timeFormatter.string(from: sleepManager.getInBedTime() )! )
                                .font(.title)
                                .fontWeight(.bold)
                        }

                        Spacer()
                        VStack {
                            Text("Asleep")
                                .font(.title2)
                                .fontWeight(.light)
                                
                            Text(Utils.timeFormatter.string(from: sleepManager.getAsleepTime() )! )
                                .font(.title)
                                .fontWeight(.bold)
                        }
                    }.padding()
        
                    VStack {
                        LineChartView(sleeps: sleepManager.sleeps, timeInBed: sleepManager.getInBedTime(), sleepsHrAverage: sleepManager.heartRateAverage)
     
                        // FOR NAPS
                        ForEach(sleepManager.naps, id: \.self) { nap in
                            Text("NAPS")
                            LineChartView(sleeps: [nap], timeInBed: (nap.endDate.timeIntervalSinceReferenceDate - nap.startDate.timeIntervalSinceReferenceDate), sleepsHrAverage: sleepManager.heartRateAverage)
                        }
                    }
                    .padding(.all, 15)
                    

                }

            }
            .navigationTitle("Sleepi")
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
            .onChange(of: sleepManager.sleeps, perform: { value in
                let deep = value.map({ $0.getStageSleepDuration(allSleepsHrAverage: sleepManager.heartRateAverage, stage: .DeepSleep) }).reduce(0, +)
                print("deep: \(Utils.timeFormatter.string(from: deep)!)")
                let rem = value.map({ $0.getStageSleepDuration(allSleepsHrAverage: sleepManager.heartRateAverage, stage: .RemSleep) }).reduce(0, +)
                print("rem: \(Utils.timeFormatter.string(from: rem)!)")
                let light = value.map({ $0.getStageSleepDuration(allSleepsHrAverage: sleepManager.heartRateAverage, stage: .LightSleep) }).reduce(0, +)
                print("light: \(Utils.timeFormatter.string(from: light)!)")
                print("total: \(Utils.timeFormatter.string(from: deep + rem + light)!)")

            })
            .gesture(DragGesture(minimumDistance: 70.0, coordinateSpace: .local)
                .onEnded { value in

                    if value.translation.width < 0 {
                        if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                                addingDays(nr: 1)
                        }
                    } else {
                        addingDays(nr: -1)
                    }
                    
//                    switch(value.translation.width, value.translation.height) {
//                        case (...0, -50...50):
//                            if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
//                                    addingDays(nr: 1)
//                            }
//                        case (0..., -50...50): addingDays(nr: -1)
//                        default: print("no clue")
//                    }
                }
            )
        }

    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portraitUpsideDown)
    }
}
