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
    
//    for _ in 1...7 {
//        let stock = Stock(price: (Int.random(in: 0...3) * 100) / 2)
//        stocks.append(stock)
//        print(stock)
//    }
    stocks = [Sleepi.Stock(price: 100), Sleepi.Stock(price: 150), Sleepi.Stock(price: 150), Sleepi.Stock(price: 50), Sleepi.Stock(price: 100), Sleepi.Stock(price: 0), Sleepi.Stock(price: 200), Sleepi.Stock(price: 200)]
    print(stocks.count)
    print(stocks)
    return stocks
}

private func getYearlyLabels() -> [String] {
    return [21, 22, 23, 24, 01, 02, 03, 04].map { String($0) }
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
                        .font(.caption)
                        .frame(width: screenWidth/CGFloat(labels.count) - 3)
                }
            }
            HStack {
                Text("Bed time")
                    .font(.caption)

                Spacer()
                Text("Rise time")
                    .font(.caption)

            }

            HStack {
                Circle()
                    .fill(Color(UIColor(named: "AppDeepSleep")!))
                    .frame(width: 10, height: 10)
                Text("Deep Sleep")
                    .font(.caption)
                
                Circle()
                    .fill(Color(UIColor(named: "AppLightSleep")!))
                    .frame(width: 10, height: 10)
                Text("Light Sleep")
                    .font(.caption)

                Circle()
                    .fill(Color(UIColor(named: "AppRemSleep")!))
                    .frame(width: 10, height: 10)
                Text("Rem Sleep")
                    .font(.caption)

                Circle()
                    .fill(Color(UIColor(named: "AppAwakeSleep")!))
                    .frame(width: 10, height: 10)
                Text("Awake")
                    .font(.caption)

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
                        .font(.title)
                    Text("27 Apr, 2022")
                        .font(.title)

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
