import SwiftUI


struct LineChartView: View {
    
    let sleeps: [Sleep]
    let timeInBed: Double
    let screenWidth: CGFloat
    
    private var path: Path {
        print("linechart sleeps.count: \(sleeps.count)")
//        print("Screenwidth: \(screenWidth)")
        
        if sleeps.isEmpty {
            return Path()
        }
        
        var path = Path()
        var offsetX = 0.0
        var offsetY: Double = SleepType.LightSleep.rawValue

        path.move(to: CGPoint(x: offsetX, y: offsetY))

        for (index, sleep) in sleeps.enumerated() {
            if index != 0 {
                path.addLine(to: CGPoint(x: offsetX, y: SleepType.LightSleep.rawValue))
            }
            
            let offset = getOffset(timeInterval: sleep.getDuration())
//            print("offset: \(offset)")
            offsetX += offset
            path.addLine(to: CGPoint(x: offsetX, y: offsetY))
            
            
            // awake time
            if index < sleeps.count - 1 {
                // make a vertical line
                path.addLine(to: CGPoint(x: offsetX, y: SleepType.Awake.rawValue))

                
                let nextAwakeTime = sleeps[index + 1].rawSleep.startDate.timeIntervalSinceReferenceDate - sleep.rawSleep.endDate.timeIntervalSinceReferenceDate
                let awakeOffset = getOffset(timeInterval: nextAwakeTime)
                offsetX += awakeOffset
                path.addLine(to: CGPoint(x: offsetX, y: SleepType.Awake.rawValue))
            }
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
    
    func getOffset(timeInterval: Double) -> Double {
        return timeInterval / timeInBed * screenWidth
    }
    
    var body: some View {
        if !sleeps.isEmpty {
        VStack {

            VStack {
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
//                    .frame(height: 150, alignment: .center)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .center)

            }

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
