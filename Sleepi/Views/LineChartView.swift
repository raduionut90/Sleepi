import SwiftUI


struct LineChartView: View {
    
    let sleeps: [Sleep]
    let timeInBed: Double
    let sleepsHrAverage: Double
    
    fileprivate func checkAwakeTime(_ index: Int, _ path: inout Path, _ offsetX: inout Double, _ offsetY: inout Double, _ sleep: Sleep, _ screenWidth: CGFloat) {
        // awake time
        if index < sleeps.count - 1 {
            // make a vertical line
            path.addLine(to: CGPoint(x: offsetX, y: SleepType.Awake.rawValue))
            
            let nextAwakeTime = sleeps[index + 1].rawSleep.startDate.timeIntervalSinceReferenceDate - sleep.rawSleep.endDate.timeIntervalSinceReferenceDate
            let awakeOffset = getOffset(timeInterval: nextAwakeTime, screenWidth: screenWidth)

            offsetX += awakeOffset
            

            path.addLine(to: CGPoint(x: offsetX, y: SleepType.Awake.rawValue))

            offsetY = SleepType.Awake.rawValue
            

        }
    }
    
    fileprivate func processEachActivity(_ sleep: Sleep, _ path: inout Path, _ offsetX: inout Double,_ offsetY: inout Double, _ screenWidth: CGFloat) {
        let activities = sleep.getActivities()
        var rectWidth = 0.0
        
        for (index, activity) in activities.enumerated() {
            let interval: Double = activity.endDate.timeIntervalSinceReferenceDate -
            (index == 0 ? sleep.rawSleep.startDate.timeIntervalSinceReferenceDate : activities[index - 1].endDate.timeIntervalSinceReferenceDate)
            
            let newOffsetY = activity.getSleepType(sleepsHrAverage).rawValue
            let offset = getOffset(timeInterval: interval, screenWidth: screenWidth)
            
            offsetX += offset
            rectWidth += offset

            if offsetY != newOffsetY{
                path.addLine(to: CGPoint(x: offsetX, y: offsetY)) //horizontal line
//                path.addRoundedRect(in: CGRect(x: offsetX - offset, y: offsetY, width: rectWidth, height: 20), cornerSize: CGSize(width: 5, height: 5), style: .circular)
//                path.move(to: CGPoint(x: offsetX, y: offsetY))
                
                path.addLine(to: CGPoint(x: offsetX, y: newOffsetY)) // vertical line
                
                rectWidth = 0.0
            }
            
            //last activity to end sleep
            if index == activities.count - 1{
                let lastInterval: Double = sleep.rawSleep.endDate.timeIntervalSinceReferenceDate - activity.endDate.timeIntervalSinceReferenceDate
                offsetX += getOffset(timeInterval: lastInterval, screenWidth: screenWidth)
                path.addLine(to: CGPoint(x: offsetX, y: newOffsetY))
            }
            offsetY = newOffsetY
        }
    }
    
    private func getPath(screenWidth: CGFloat) -> Path {
//        print("linechart sleeps.count: \(sleeps.count)")
//        print("Screenwidth: \(screenWidth)")
        
        if sleeps.isEmpty {
            return Path()
        }
        
        var path = Path()
        var offsetX = 0.0
        var offsetY = SleepType.LightSleep.rawValue

        path.move(to: CGPoint(x: offsetX, y: SleepType.LightSleep.rawValue))

        for (index, sleep) in sleeps.enumerated() {
            
            processEachActivity(sleep, &path, &offsetX, &offsetY, screenWidth)
            
            checkAwakeTime(index, &path, &offsetX, &offsetY, sleep, screenWidth)
        }
//        for sleepPoint in sleepPoints {
//            path.addRoundedRect(in: CGRect(x: offsetX, y: offsetY - 10, width: sleepPoint.offsetX - offsetX, height: 20), cornerSize: CGSize(width: 5, height: 5), style: .circular)
//            path.addLine(to: CGPoint(x: sleepPoint.offsetX, y: sleepPoint.type))
//
//            offsetX = sleepPoint.offsetX
//            offsetY = sleepPoint.type
//        }
        return path
    }
    
    private func getOffset(timeInterval: Double, screenWidth: CGFloat) -> Double {
        return timeInterval / timeInBed * screenWidth
    }
    
    var body: some View {
        if !sleeps.isEmpty {
        VStack {
            HStack {
                VStack {
                    Text("awake")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .frame(maxHeight: .infinity)

                    Text("rem")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .frame(maxHeight: .infinity)


                    Text("light")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .frame(maxHeight: .infinity)

                    Text("deep")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .frame(maxHeight: .infinity)

                }
//                .background(.red)

                
                VStack {
                    GeometryReader { geo in
//                        let _ = print(geo.size.width)
                  

                        getPath(screenWidth: geo.size.width).stroke(
                            LinearGradient(gradient: Gradient(colors:
                                                                [
                                                                    Color(UIColor(named: "AppDeepSleep")!),
                                                                    Color(UIColor(named: "AppLightSleep")!),
                                                                    Color(UIColor(named: "AppRemSleep")!),
                                                                    Color(UIColor(named: "AppAwakeSleep")!)
                                                                ]), startPoint: .top, endPoint: .bottom), lineWidth: 1.0)
                            .rotationEffect(.degrees(180), anchor: .center)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        //                    .frame(height: 150, alignment: .center)
                        
                    }
                        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .center)

                }
                .cornerRadius(1)
                .padding(.vertical)

            }
            .padding(.vertical)
            .padding(.horizontal, 5.0)
            .frame(maxWidth: .infinity, maxHeight: 300)
            .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray, lineWidth: 1)
            )

            HStack {
                Text("Bed time").font(.caption)
                Spacer()
                Text("Rise time").font(.caption)
            }
            HStack {
                
                Text((sleeps.first?.rawSleep.startDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
                Spacer()
                Text((sleeps.last?.rawSleep.endDate)!, formatter: Utils.hhmmtimeFormatter).font(.caption)
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
}
