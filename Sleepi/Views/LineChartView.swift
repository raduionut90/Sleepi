import SwiftUI


struct LineChartView: View {
    @State var chartLineOffsetX: Double = 0.0
    @State var chartLineIsVisible: Bool = false
    @State var chartWidth: Double = 0.0
    @State var chartLineDate: Date = Date()
    
    let sleeps: [Sleep]
    let timeInBed: Double
    let sleepsHrAverage: Double
    
    private func setChartLineDate(){
        let startDate = (sleeps.first?.startDate.timeIntervalSinceReferenceDate)!
        let endDate = (sleeps.last?.endDate.timeIntervalSinceReferenceDate)!
        
        let xPercent =  chartLineOffsetX / chartWidth * 100
        let result = (endDate - startDate) * xPercent / 100
        
        let date = Date(timeIntervalSinceReferenceDate: startDate + result)
        chartLineDate = date
    }
    
    fileprivate func checkAwakeTime(_ index: Int, _ path: inout Path, _ offsetX: inout Double, _ offsetY: inout Double, _ sleep: Sleep, _ screenWidth: CGFloat) {
        // awake time
        if index < sleeps.count - 1 {
            // make a vertical line
            path.addLine(to: CGPoint(x: offsetX, y: SleepStage.Awake.rawValue))
            
            let nextAwakeTime = sleeps[index + 1].startDate.timeIntervalSinceReferenceDate - sleep.endDate.timeIntervalSinceReferenceDate
            let awakeOffset = getOffset(timeInterval: nextAwakeTime, screenWidth: screenWidth)

            offsetX += awakeOffset
            

            path.addLine(to: CGPoint(x: offsetX, y: SleepStage.Awake.rawValue))

            offsetY = SleepStage.Awake.rawValue
            

        }
    }
    
    fileprivate func processEachActivity(_ sleep: Sleep, _ path: inout Path, _ offsetX: inout Double,_ offsetY: inout Double, _ screenWidth: CGFloat) {
        var rectWidth = 0.0
//        print("sleepStart: \(sleep.rawSleep.startDate.formatted())")
        for (index, activity) in sleep.activities.enumerated() {
            let interval: Double = activity.endDate!.timeIntervalSinceReferenceDate -
            (index == 0 ? sleep.startDate.timeIntervalSinceReferenceDate : sleep.activities[index - 1].endDate!.timeIntervalSinceReferenceDate)
            
            let newOffsetY = activity.stage == nil ? SleepStage.LightSleep.rawValue : activity.stage!.rawValue 
            let offset = getOffset(timeInterval: interval, screenWidth: screenWidth)
            
//            print("\(activity.startDate.formatted()); \(activity.hr!); \(activity)")
            
            offsetX += offset
            rectWidth += offset

            if offsetY != newOffsetY{
                path.addLine(to: CGPoint(x: offsetX, y: offsetY)) //horizontal line
//                path.addRoundedRect(in: CGRect(x: offsetX - rectWidth, y: offsetY - 10, width: rectWidth, height: 20), cornerSize: CGSize(width: 5, height: 5), style: .circular)
//                path.move(to: CGPoint(x: offsetX, y: offsetY))
                
                path.addLine(to: CGPoint(x: offsetX, y: newOffsetY)) // vertical line
                
                rectWidth = 0.0
            }
            
            //last activity to end sleep
            if index == sleep.activities.count - 1{
                let lastInterval: Double = sleep.endDate.timeIntervalSinceReferenceDate - activity.endDate!.timeIntervalSinceReferenceDate
                offsetX += getOffset(timeInterval: lastInterval, screenWidth: screenWidth)
                path.addLine(to: CGPoint(x: offsetX, y: newOffsetY))
            }
            offsetY = newOffsetY
        }

    }
    
    private var path: Path {
//        print("linechart sleeps.count: \(sleeps.count)")
//        print("Screenwidth: \(screenWidth)")
        
        if sleeps.isEmpty {
            return Path()
        }
        
        var path = Path()
        var offsetX = 0.0
        var offsetY = SleepStage.LightSleep.rawValue

        path.move(to: CGPoint(x: offsetX, y: SleepStage.LightSleep.rawValue))

        for (index, sleep) in sleeps.enumerated() {
            
            processEachActivity(sleep, &path, &offsetX, &offsetY, chartWidth)
            
            checkAwakeTime(index, &path, &offsetX, &offsetY, sleep, chartWidth)
        }
        return path
    }
    
    private func getOffset(timeInterval: Double, screenWidth: CGFloat) -> Double {
        return timeInterval / timeInBed * screenWidth
    }
    
    private func setChartWidth(_ geometry: GeometryProxy) -> some View {

        DispatchQueue.main.async {
            self.chartWidth = geometry.size.width
        }

        return EmptyView()
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
                        if !sleeps.isEmpty {
                            VStack {
                                GeometryReader { geo in
                                    setChartWidth(geo)
                                    path.stroke(
                                        LinearGradient(gradient: Gradient(colors:
                                                                            [
                                                                                Color(UIColor(named: "AppDeepSleep")!),
                                                                                Color(UIColor(named: "AppLightSleep")!),
                                                                                Color(UIColor(named: "AppRemSleep")!),
                                                                                Color(UIColor(named: "AppAwakeSleep")!)
                                                                            ]), startPoint: .top, endPoint: .bottom), lineWidth: 1.0)
                                        .rotationEffect(.degrees(180), anchor: .center)
                                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
//                                        .frame(width: 300, height: 150, alignment: .center)
                                    
                                }
                                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .center)
                            }
                            VStack {
                                if chartLineIsVisible {
                                    Path { path in
                                          path.move(to: CGPoint(x: chartLineOffsetX, y: 0))
                                          path.addLine(to: CGPoint(x: chartLineOffsetX, y: 150))
                                    }.stroke(.gray)
                                }
                            }
                        } else {
                            Spacer()
                        }
                    }
                    .background(Color("BackgroundSec"))
//                    .foregroundColor(.green)
                    .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
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
                .padding(.horizontal, 5.0)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                            .stroke(.gray, lineWidth: 1))
            }

            VStack {
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
                    Spacer()
                }
            }
            .frame(minHeight: 30)
            
        }
        
    }
}
