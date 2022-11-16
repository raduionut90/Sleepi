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
    @State var chartLineStageStart: Date = Date()
    @State var chartLineStageEnd: Date = Date()
    let timeInBed: Double
    let sleeps: [Sleep]
    
    init(sleeps: [Sleep]) {
        self.sleeps = sleeps

        if sleeps.isEmpty {
            self.timeInBed = 0.0
        } else {
            self.timeInBed = sleeps.last!.endDate.timeIntervalSinceReferenceDate - sleeps.first!.startDate.timeIntervalSinceReferenceDate
        }
    }
    
    private func setChartLineStageDate(){
        let sleep = sleeps.first(where: {$0.startDate < chartLineDate && $0.endDate > chartLineDate})
        if let sleep = sleep {
            self.chartLineStageStart = sleep.startDate
            self.chartLineStageEnd = sleep.endDate
        }
    }
    
    private func setChartLineDate(){
        let startDate = (sleeps.first?.startDate.timeIntervalSinceReferenceDate)!
        let endDate = (sleeps.last?.endDate.timeIntervalSinceReferenceDate)!
        
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
        case .Nap:
            return Color(UIColor(named: "AppAwakeSleep")!)
        }
    }
    
    private func getOffsetYbyStage(_ stage: SleepStage) -> Double {
        switch stage {
        case .DeepSleep:
            return 150.0
        case .LightSleep:
            return 100.0
        case .RemSleep:
            return 50.0
        case .Awake:
            return 0.0
        case .Nap:
            return 0.0
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                if chartLineIsVisible {
                    VStack {
                        HStack {
                            Text(chartLineStageStart, formatter: Utils.hhmmtimeFormatter)
                                .font(.caption)
                            .foregroundColor(.gray)
                            Text("-")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(chartLineStageEnd, formatter: Utils.hhmmtimeFormatter)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
                HStack {
                    ZStack {
                        if !sleeps.isEmpty {
                            VStack {
                                GeometryReader { geo in
                                    setChartWidth(geo)
                                    ForEach(Array(zip(sleeps.indices, sleeps)), id: \.0) { index, sleepStage in
                                        let interval: Double = sleepStage.endDate.timeIntervalSinceReferenceDate - sleepStage.startDate.timeIntervalSinceReferenceDate
                                        let offset: Double = interval / timeInBed * chartWidth

                                        let startPoint: Double = (sleepStage.startDate.timeIntervalSinceReferenceDate - sleeps.first!.startDate.timeIntervalSinceReferenceDate) /
                                        timeInBed * chartWidth

                                        let color: Color = getColor(stage: sleepStage.stage!)
                                        HorizontalBar(x: startPoint, y: getOffsetYbyStage(sleepStage.stage!), width: offset, height: 20).fill(color)
                                        if sleeps.indices.contains(index - 1) {
                                            let y: Double = getOffsetYbyStage(sleeps[index - 1].stage!) + 10.0
                                            let newY: Double = getOffsetYbyStage(sleepStage.stage!) + 10.0
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
                            setChartLineStageDate()
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
                if chartLineIsVisible {
                    VStack {
                        Spacer()
                        Text(chartLineDate, formatter: Utils.hhmmtimeFormatter)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 200)

            VStack {
               Group {
                    HStack {
                        Text("Bed time").font(.caption)
                        Spacer()
                        Text("Rise time").font(.caption)
                    }
                    if !sleeps.isEmpty {
                        HStack {
                                Text((sleeps.first?.startDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
                                Spacer()
                                Text((sleeps.last?.endDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
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
                  stage: .RemSleep),
            Sleep(startDate: Calendar.current.date(byAdding: .hour, value: -7, to: Date())!,
                  endDate: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
                  stage: .Awake),
            Sleep(startDate: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
                  endDate: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!,
                  stage: .DeepSleep)
        ])
    }
}
