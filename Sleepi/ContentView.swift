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
    private var healthStore: HealthStore?
    @State private var sleeps: [Sleep] = [Sleep]()
    @State private var date: Date = Date()
    @State private var startSleep: Date = Date.init(timeIntervalSince1970: 0)
    @State private var endSleep: Date = Date.init(timeIntervalSince1970: 0)
    @State private var timeDiff: Double = 0
    @State private var heartRates: [HeartRate] = [HeartRate]()

    init(){
        sleeps = []
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HealthStore()
        }
    }

    private func getSleepPoints() -> [SleepPoint] {

        var sleepPoints = [SleepPoint]()
        let screenWidth = UIScreen.main.bounds.width - 30
        var lastEndTime: Date = Date.init(timeIntervalSince1970: 0)
        
        print("Sleeps.count: " + "\(sleeps.count)")
        
        if (sleeps.count == 0 || timeDiff == 0) {
            return []
        }

        var offsetX: Double = 0
        for sleep in sleeps {
            if (lastEndTime != Date.init(timeIntervalSince1970: 0) && lastEndTime < sleep.startDate && timeDiff != 0){
                let sleepType = (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 10 * 60 ?
                SleepType.RemSleep.rawValue : SleepType.Awake.rawValue
                
                print("type: \((sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) < 160)")
                print("type: \((lastEndTime.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) )")

                let startPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(startPoint)

                let sleepPercent: Double = ( (sleep.startDate.timeIntervalSinceReferenceDate - lastEndTime.timeIntervalSinceReferenceDate) / timeDiff )
                let offset = (sleepPercent) * screenWidth
                offsetX += offset

                let endPoint = SleepPoint(
                    type: sleepType,
                    offsetX: offsetX)
                sleepPoints.append(endPoint)

            }

            let startPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(startPoint)

            let sleepPercent = ((sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate) / timeDiff )
            let offset = (sleepPercent) * screenWidth
            offsetX += offset

            let endPoint = SleepPoint(
                type: SleepType.LightSleep.rawValue,
                offsetX: offsetX)
            sleepPoints.append(endPoint)

            lastEndTime = sleep.endDate
        }

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
    
    func addingDays(nr: Int) -> Void {
        var dateComponent = DateComponents()
        dateComponent.day = nr
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: date)
        self.date = futureDate!
    }
    
    func loadSleeps() {
        if let healthStore = healthStore {
            healthStore.requestAuthorization{ success in
                if success {
                    healthStore.startSleepQuery(date: date){samples in
                        var newSleeps: [Sleep] = []
                        print("ssamples.count: \(samples.count)")
                        for item in samples {
                            if let sample = item as? HKCategorySample {
                                let value = (sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue) ? "InBed" : "Asleep"
                                if (sample.sourceRevision.source.bundleIdentifier.contains("com.apple.health") &&
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
                        calculateMinAndMaxSleepTime()
//
                        healthStore.startHeartRateQuery(startDate: startSleep, endDate: endSleep){ samples in
                            if let samples = samples {
                                for item in samples{
                                    let heartRate = HeartRate(value: item.quantity.doubleValue(for: HKUnit(from: "count/min")), startDate: item.startDate)
                                    heartRates.append(heartRate)
                                }
                                print("heartRates.count: \(heartRates.count)")

                            }
                        }
                    }
                        

                }
            }

        }
        
    }
    
    func getSleptTime() -> DateComponents {
        let difference = Calendar.current.dateComponents([.hour, .minute], from: startSleep, to: endSleep)
        return difference
    }
    
    private func calculateMinAndMaxSleepTime() {
        if let earliest = sleeps.min(by: { $0.startDate < $1.startDate }) {
            // use earliest reminder
            startSleep = earliest.startDate
        }
        if let latest = sleeps.max(by: { $0.endDate < $1.endDate }) {
            // use earliest reminder
            endSleep = latest.endDate
        }
        timeDiff = endSleep.timeIntervalSinceReferenceDate - startSleep.timeIntervalSinceReferenceDate
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
                    LineChartView(sleepPoints: getSleepPoints(), labels: getHourLabels(),
                                  startSleep: startSleep, endSleep: endSleep)
                }.padding()
               
                
                Spacer()

                List(sleeps, id: \.id) { sleep in
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
                loadSleeps()
            }
            .onChange(of: date, perform: { value in
                loadSleeps()
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.portrait)
    }
}
