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
    let type: Int
    let offsetX: Double
}


struct ContentView: View {
    private var healthStore: HealthStore?
    @State private var sleeps: [Sleep] = [Sleep]()
    @State private var date: Date = Date()
    @State private var startSleep: Date = Date.init(timeIntervalSince1970: 0)
    @State private var endSleep: Date = Date.init(timeIntervalSince1970: 0)
    @State private var timeDiff: Double = 0

    init(){
        sleeps = []
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HealthStore()
        }
    }

    private func getHistoricalStocks() -> [SleepPoint] {

        var sleepPoints = [SleepPoint]()
        let screenWidth = UIScreen.main.bounds.width - 30
        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)

        var offsetX: Double = 0
        print("sleeps.count: " + "\(sleeps.count)")
        for sleep in sleeps {
            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && timeDiff != 0){
                print("timediff: " + "\(timeDiff)")

                let diff = sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate
                let sleepPercent: Double = (diff / timeDiff ) * 100
                let offsetPercent = (sleepPercent / 100) * screenWidth
                let sleepPoint = SleepPoint(
                    type: 150,
                    offsetX: offsetX)
                offsetX += offsetPercent
                sleepPoints.append(sleepPoint)
                let sleepPoint2 = SleepPoint(
                    type: 150,
                    offsetX: offsetX)
                sleepPoints.append(sleepPoint2)
            }
            
            print("offsetX: " + "\(offsetX)")
            print("sleep: " + "\(sleep)")

            print("sleepDiff : " + "\(sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate)")
            print(((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate)/timeDiff)*100)
            let sleepPercent = ((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) / timeDiff ) * 100
            let offsetPercent = (sleepPercent / 100) * screenWidth
            print("offpercent: " + offsetPercent.description)

            let sleepPoint = SleepPoint(
                type: 0,
                offsetX: offsetX)
            sleepPoints.append(sleepPoint)
            offsetX += offsetPercent
            
            let sleepPoint2 = SleepPoint(
                type: 0,
                offsetX: offsetX)
            sleepPoints.append(sleepPoint2)
            lastEndTime = sleep.endDate
        }
//        print("timediff: " + "\(timeDiff)")

        return sleepPoints
    }
    
    private func getHourLabels() -> [String] {
        var hours: [Int] = []
        let startHour = Calendar.current.component(.hour, from: startSleep)
        let endHour = Calendar.current.component(.hour, from: endSleep)

        if (startHour > endHour) {
            for h in startHour ... 24 {
                if h == 24{
                    hours.append(0)
                } else {
                    hours.append(h)

                }
            }
            for h in 1 ... endHour {
                hours.append(h)
            }
        } else {
            for h in startHour ... endHour {
                hours.append(h)
            }
        }

//            hours.append(startHour)
//            hours.append(endHour)
        
//        hours = Array(Set(hours))
//        hours.sort()
        return hours.map { String($0) }
    }

    private var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, dd MMM yyyy, HH:mm"
        return formatter
    }()
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    private var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
//    let prices = getHistoricalStocks().map { Int($0.price) }
//    let labels = getYearlyLabels()
    
    func addingDays(nr: Int) -> Void {
        var dateComponent = DateComponents()
        dateComponent.day = nr
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: date)
        self.date = futureDate!
    }
    
    func reloadSleeps() {
        
        if let healthStore = healthStore {
            healthStore.requestAuthorization{ success in
                if success {
                    healthStore.calculateSleep(){samples in
                        var newSleeps: [Sleep] = []
                        for item in samples {
                            if let sample = item as? HKCategorySample {
                                let value = (sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue) ? "InBed" : "Asleep"
                                if (Calendar.current.compare(sample.endDate.addingTimeInterval(7200), to: date, toGranularity: .day) == .orderedSame &&
                                    sample.sourceRevision.source.bundleIdentifier.contains("com.apple.health") &&
                                    ((sample.sourceRevision.productType?.contains("Watch")) == true)) {
                                    print("Healthkit sleep: \(sample.startDate) \(sample.endDate) value: \(value)")
                                    let sleep = Sleep(value: sample.value, startDate: sample.startDate, endDate: sample.endDate, source: sample.sourceRevision.source.name)
                                    newSleeps.append(sleep)
                                    print(sample.value)
                                    print(sample.sourceRevision)
                                    print("")
                                }
                                
                            }
                        }
                        newSleeps.sort(by: {$0.startDate < $1.startDate})
                        sleeps = newSleeps

                    }
                }
            }

        }

    }
    
    func getSleptTime() -> DateComponents {
        print(startSleep)
        print(endSleep)
        let difference = Calendar.current.dateComponents([.hour, .minute], from: startSleep, to: endSleep)
        print("differecnce")
        print(difference)
        return difference
    }
    
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
                    Text(dateFormatter.string(from: date))
                        .font(.title)
                    if (Calendar.current.compare(Date(), to: date, toGranularity: .day) == .orderedDescending) {
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

                Text(getSleptTime(), formatter: timeFormatter).padding(.bottom)
                
                VStack{
                    LineChartView(sleepPoints: getHistoricalStocks(), labels: getHourLabels(),
                                  startSleep: startSleep, endSleep: endSleep)
                }.padding()
               
                
                Spacer()

                List(sleeps, id: \.id) { sleep in
                    VStack(alignment: .leading){
                        Text("sleeps.count: " + "\(sleeps.count)")

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
                reloadSleeps()
            }
            .onChange(of: date, perform: { value in
                reloadSleeps()
            })
            .onChange(of: sleeps, perform: { value in
                if let earliest = sleeps.min(by: { $0.startDate < $1.startDate }) {
                    // use earliest reminder
                    startSleep = earliest.startDate
                }
                if let latest = sleeps.max(by: { $0.endDate < $1.endDate }) {
                    // use earliest reminder
                    endSleep = latest.endDate
                }
                timeDiff = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
                
            })

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
