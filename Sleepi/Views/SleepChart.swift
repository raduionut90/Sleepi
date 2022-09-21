//
//  SleepChart.swift
//  Sleepi
//
//  Created by Ionut Radu on 19.09.2022.
//

import SwiftUI

struct SleepChart: View {
    @State var chartLineOffsetX: Double = 0.0
    @State var chartLineIsVisible: Bool = false
    @State var chartWidth: Double = 0.0
    @State var chartLineDate: Date = Date()
    let timeInBed: Double
    let sleeps: [Sleep]
    var epochs: [Epoch] = []
    
    init(sleeps: [Sleep]) {
        self.sleeps = sleeps
        for (index, sleep) in sleeps.enumerated() {
            epochs.append(contentsOf: sleep.epochs)
            if sleeps.indices.contains(index + 1) {
                epochs.append(Epoch(start: sleep.endDate, end: sleeps[index + 1].startDate, records: [], stage: .Awake))
            }
        }
        
        if sleeps.isEmpty {
            self.timeInBed = 0.0
        } else {
            self.timeInBed = sleeps.last!.endDate.timeIntervalSinceReferenceDate - sleeps.first!.startDate.timeIntervalSinceReferenceDate
        }
        self.epochs = processEpochs(epochs: epochs)
    }
    
    private func processEpochs(epochs: [Epoch]) -> [Epoch] {
        var result: [Epoch] = []
        for (index, epoch) in epochs.enumerated(){
            if epochs.indices.contains(index + 1) {
                epoch.endDate = epochs[index + 1].startDate
            } else {
                epoch.endDate = sleeps.last!.endDate
            }
            if result.isEmpty {
                result.append(epoch)
            } else {
                if result.last!.stage != epoch.stage && epoch != epochs.last {
                    result.last!.endDate = epoch.startDate
                    result.append(epoch)
                } else if epoch == epochs.last {
                    result.last!.endDate = epoch.endDate
                }
            }
        }
        return result
    }
    
    private func setChartLineDate(){
        let startDate = (epochs.first?.startDate.timeIntervalSinceReferenceDate)!
        let endDate = (epochs.last?.endDate.timeIntervalSinceReferenceDate)!
        
        let xPercent =  chartLineOffsetX / chartWidth * 100
        let result = (endDate - startDate) * xPercent / 100
        
        let date = Date(timeIntervalSinceReferenceDate: startDate + result)
        chartLineDate = date
    }
    
    private func setChartWidth(_ geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.chartWidth = geometry.size.width
        }
        return EmptyView()
    }
    
    private func getColor(stage: SleepStage) -> Color {
        switch stage {
        case .DeepSleep:
            return Color(UIColor(named: "AppDeepSleep")!)
        case .LightSleep:
            return Color(UIColor(named: "AppLightSleep")!)
        case .RemSleep:
            return Color(UIColor(named: "AppRemSleep")!)
        case .Awake:
            return Color(UIColor(named: "AppAwakeSleep")!)
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                if chartLineIsVisible {
                    VStack {
                        Text(chartLineDate, formatter: Utils.hhmmtimeFormatter)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                HStack {
                    ZStack {
                        if !epochs.isEmpty {
                            VStack {
                                GeometryReader { geo in
                                    setChartWidth(geo)
                                    ForEach(Array(zip(epochs.indices, epochs)), id: \.0) { index, epoch in
                                        let interval: Double = epoch.endDate.timeIntervalSinceReferenceDate - epoch.startDate.timeIntervalSinceReferenceDate
                                        let offset: Double = interval / timeInBed * chartWidth
                                        
                                        let startPoint: Double = (epoch.startDate.timeIntervalSinceReferenceDate - sleeps.first!.startDate.timeIntervalSinceReferenceDate) /
                                        timeInBed * chartWidth
                                        
                                        let color: Color = getColor(stage: epoch.stage!)
                                        HorizontalBar(x: startPoint, y: epoch.stage!.rawValue, width: offset, height: 20).fill(color)
                                        if epochs.indices.contains(index - 1) {
                                            let y = epochs[index - 1].stage!.rawValue + 10
                                            let newY = epoch.stage!.rawValue + 10
                                            VerticalLine(startPoint: CGPoint(x: startPoint, y: y), x: startPoint, y: newY)
                                                .stroke(.gray, lineWidth: 0.2)
                                        }
                                    }
                                    
                                }
                                .padding(.leading, 5)
                                .padding(.trailing, 5)
                                .frame(minHeight: 150, maxHeight: 150, alignment: .center)

                            }
                            VStack {
                                if chartLineIsVisible {
                                    Path { path in
                                          path.move(to: CGPoint(x: chartLineOffsetX, y: 0))
                                          path.addLine(to: CGPoint(x: chartLineOffsetX, y: 170))
                                    }.stroke(.gray)
                                }
                            }
                            .padding(.leading, 5)
                            .padding(.trailing, 5)
                            .frame(minHeight: 150, maxHeight: 150)
                        } else {
                            Spacer()
                        }
                    }
                    .background(Color("BackgroundSec"))
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
//                            print(value.translation)
                            chartLineIsVisible = true
                            chartLineOffsetX = value.startLocation.x

                            if chartLineOffsetX + value.translation.width < 0 {
                                chartLineOffsetX = 0
                            } else if chartLineOffsetX + value.translation.width > chartWidth {
                                chartLineOffsetX = chartWidth
                            } else {
                                chartLineOffsetX += value.translation.width
                            }
                            setChartLineDate()
                        }
                        .onEnded { _ in
                            chartLineIsVisible = false
                        }
                    )
                    .frame(minWidth: 300, minHeight: 150)
                    
                }
                .padding(.vertical)
                .padding(.top, 5.0)
                .padding(.bottom, 25.0)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray, lineWidth: 0.3)
                        )
            }
            .frame(minHeight: 200, maxHeight: 200)

            VStack {
               Group {
                    HStack {
                        Text("Bed time").font(.caption)
                        Spacer()
                        Text("Rise time").font(.caption)
                    }
                    if !epochs.isEmpty {
                        HStack {
                                Text((epochs.first?.startDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
                                Spacer()
                                Text((epochs.last?.endDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                    }
                }
            }
            .frame(minHeight: 30, maxHeight: 30)
        }
        
    }
}

struct SleepChart_Previews: PreviewProvider {
    static var previews: some View {
        SleepChart(sleeps: [
            Sleep(startDate: Calendar.current.date(byAdding: .hour, value: -10, to: Date())!,
                  endDate: Calendar.current.date(byAdding: .hour, value: -7, to: Date())!,
                  epochs: [
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -10, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -9, to: Date())!, records: [], stage: .DeepSleep),
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -9, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!, records: [], stage: .RemSleep)
                    ,
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -7, to: Date())!, records: [], stage: .LightSleep)
                  ] ),
            Sleep(startDate: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
                  endDate: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!,
                  epochs: [
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!, records: [], stage: .DeepSleep),
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!, records: [], stage: .LightSleep)
                    ,
                    Epoch(start: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!, end: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!, records: [], stage: .RemSleep)
                  ] )
        ])
    }
}
