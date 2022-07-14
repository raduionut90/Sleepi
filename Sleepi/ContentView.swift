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
    @StateObject var sleepManager: SleepManager = SleepManager()
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
                    .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                    Spacer()
                    VStack {
                        Text("Asleep")
                            .font(.title2)
                            .fontWeight(.light)
                            
                        Text(Utils.timeFormatter.string(from: sleepManager.getAsleepTime() )! )
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                }.padding()

                
                GeometryReader { geo in
    
                    VStack {
                        LineChartView(sleeps: sleepManager.sleeps, timeInBed: sleepManager.getInBedTime(), screenWidth: geo.size.width)
                    }

                    // FOR NAPS

                        
                    VStack {
                        ForEach(sleepManager.naps, id: \.self) { nap in
                                VStack {
                                    Spacer()

                                    Text("NAPS")

                                    LineChartView(sleeps: [nap], timeInBed: (nap.rawSleep.endDate.timeIntervalSinceReferenceDate - nap.rawSleep.startDate.timeIntervalSinceReferenceDate), screenWidth: geo.size.width)
                                }

                        }
                    }

                }
 
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
        }

    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portraitUpsideDown)
    }
}
