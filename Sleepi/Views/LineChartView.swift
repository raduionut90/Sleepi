import SwiftUI

struct LineChartView: View {
    
    let sleepPoints: [SleepPoint]
    let labels: [String]
    let startSleep: Date
    let endSleep: Date
    
    let screenWidth = UIScreen.main.bounds.width - 10
    
    private var path: Path {
        
        if sleepPoints.isEmpty {
            return Path()
        }
        
        var path = Path()
        path.move(to: CGPoint(x: sleepPoints[0].offsetX, y: sleepPoints[0].type))
        
        for sleepPoint in sleepPoints {
            path.addLine(to: CGPoint(x: sleepPoint.offsetX, y: sleepPoint.type))
        }
        return path
        
    }
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack {

            ZStack {
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
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
//                        .frame(width: screenWidth/CGFloat(labels.count))
                    if (label != labels.last){
                        Spacer()
                    }
                }
            }

            HStack {
                Text("Bed time").font(.caption)
                Spacer()
                Text("Rise time").font(.caption)
            }
            HStack {
                Text(startSleep, formatter: timeFormatter).font(.caption)
                Spacer()
                Text(endSleep, formatter: timeFormatter).font(.caption)
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
