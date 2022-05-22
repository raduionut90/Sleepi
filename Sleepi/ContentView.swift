//
//  ContentView.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI
import HealthKit
import SwiftUICharts

struct SleepPoint {
    let type: Double
    let offsetX: Double
}

struct ContentView: View {
    @State private var currentDate: Date = Date()
    @StateObject var sleepManager: SleepManager = SleepManager(date: Date(), screenWidth: UIScreen.main.bounds.width - 30)
    
    init() {
//        print("sleepManager.sleeps: \(sleepManager.sleeps?.count ?? 0)")
//        sleepManager.readSleeps()

//        print("sleepManager.count: \(sleepManager.sleeps?.count ?? 0)")
    }
    
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
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    var body: some View {

        NavigationView{
            VStack {
//                HStack {
//                    Text("Day").underline()
//                    Text("Week")
//                    Text("Month")
//                    Text("Year")
//                }
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

                Text((sleepManager.getSleptTime()), formatter: timeFormatter).padding(.bottom)
                
                VStack{
                    LineChartView(sleepPoints: sleepManager.sleepPoints, labels: sleepManager.getHourLabels(),
                                  startSleep: sleepManager.startSleep, endSleep: sleepManager.endSleep)
                }.padding()
                               
                Spacer()

                List(sleepManager.sleeps , id: \.id) { sleep in
                        VStack(alignment: .leading){
                            Text("\(sleep.value)")
                            Text(sleep.startDate,  formatter: formatter).opacity(0.5)
                            Text(sleep.endDate, formatter: formatter).opacity(0.5)
                            Text(sleep.source)
                        }
                    }
            }
            .navigationTitle("Sleepi")
        }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear(){
//                sleepManager.readSleeps()

            }
            .onChange(of: currentDate, perform: { value in
//                refreshSleeps()
//                await sleepManager.readSleeps(date: value)
                sleepManager.refreshSleeps(date: value)
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portrait)
    }
}
