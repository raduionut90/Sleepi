//
//  ContentView.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI
import HealthKit
import SwiftUICharts

struct Stock {
    let price: Int
}

private func getHistoricalStocks() -> [Stock] {
    
    var stocks = [Stock]()
    
    for _ in 1...20 {
        let stock = Stock(price: (Int.random(in: 0...3) * 100) / 2)
        stocks.append(stock)
        print(stock)
    }
    return stocks
}

private func getYearlyLabels() -> [String] {
    return (2015...2021).map { String($0) }
}

struct LineChartView: View {
    
    let values: [Int]
    let labels: [String]
    
    let screenWidth = UIScreen.main.bounds.width
    
    private var path: Path {
        
        if values.isEmpty {
            return Path()
        }
        
        var offsetX: Int = Int(screenWidth/CGFloat(values.count))
        var path = Path()
        path.move(to: CGPoint(x: offsetX, y: values[0]))
        
        for value in values {
            offsetX += Int(screenWidth/CGFloat(values.count))
            path.addLine(to: CGPoint(x: offsetX, y: value))
        }
        
        return path
        
    }
    
    var body: some View {
        VStack {

            path.stroke(
                LinearGradient(gradient: Gradient(colors:
                                                    [
                                                        Color(UIColor(named: "AppDeepSleep")!),
                                                        Color(UIColor(named: "AppLightSleep")!),
                                                        Color(UIColor(named: "AppRemSleep")!),
                                                        Color(UIColor(named: "AppAwakeSleep")!)
                                                    ]), startPoint: .top, endPoint: .bottom), lineWidth: 3.0)
                .rotationEffect(.degrees(180), anchor: .center)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .frame(maxWidth: .infinity, maxHeight: 150)
            
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .frame(width: screenWidth/CGFloat(labels.count) - 10)
                        .foregroundColor(Color.black)
                }
            }
            
        }
    }
}

struct ContentView: View {
    private var healthStore: HealthStore?
    @State private var sleeps: [Sleep] = [Sleep]()
    
    init(){
        sleeps = []
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HealthStore()
        }
    }
    
    private var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, dd MMM yyyy, HH:MM"
        return formatter
    }()
    

    
    let prices = getHistoricalStocks().map { Int($0.price) }
    let labels = getYearlyLabels()
    
    var body: some View {
        NavigationView{
            VStack {
                HStack {
                    Text("Day").underline()
                    Text("Week")
                    Text("Month")
                    Text("Year")
                }
                HStack{
                    Spacer()
                    Text("<")
                    Text("27 Apr, 2022")
                    Spacer()
                }.padding()
                Text("Night Sleep / Nap")
                Text("7h 28m")
                LineChartView(values: prices, labels: labels).padding()
                List(sleeps, id: \.id) { sleep in
                    VStack(alignment: .leading){
                        Text("\(sleep.value)")
                        Text(sleep.startDate,  formatter: formatter).opacity(0.5)
                        Text(sleep.endDate, formatter: formatter).opacity(0.5)
                    }

                }
            }
            .navigationTitle("Sleepi")
        }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear{
                if let healthStore = healthStore {
                    healthStore.requestAuthorization{ success in
                        if success {
                            healthStore.calculateSleep(){samples in
                                for item in samples {
                                    if let sample = item as? HKCategorySample {
                                        let value = (sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue) ? "InBed" : "Asleep"
                                            print("Healthkit sleep: \(sample.startDate) \(sample.endDate) value: \(value)")
                                        let sleep = Sleep(value: value, startDate: sample.startDate, endDate: sample.endDate)
                                        sleeps.append(sleep)
                                        print(sample.metadata?.description ?? "")
                                        print(sample.sourceRevision)
                                        print("")
                                        
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
