import SwiftUI


struct LineChartView: View {
    
    @State var speed: TimeInterval
    @State private var isEditing = false
    
    let sleepPoints: [SleepPoint]
    let labels: [HourItem]
    let startSleep: Date
    let endSleep: Date
    let screenWidth = UIScreen.main.bounds.width - 10
    
//    private func getPath() -> [Path] {
//        if sleepPoints.isEmpty {
//            return [Path()]
//        }
//        
//        var paths: [Path] = []
//        var x = sleepPoints[0].offsetX
//        var y = sleepPoints[0].type
//        
//        for sleepPoint in sleepPoints {
//            var path = Path()
//            path.move(to: CGPoint(x: x, y: y))
//            path.addLine(to: CGPoint(x: sleepPoint.offsetX, y: sleepPoint.type))
//        }
//    }
    
    private var path: Path {
        
        if sleepPoints.isEmpty {
            return Path()
        }
        
        var path = Path()
        var offsetX = 0.0
        var offsetY = sleepPoints[0].type
        path.move(to: CGPoint(x: offsetX, y: offsetY))

        print("sleeppoint.count: \(sleepPoints.count)")
        for sleepPoint in sleepPoints {            
            path.addRoundedRect(in: CGRect(x: offsetX, y: offsetY - 10, width: sleepPoint.offsetX - offsetX, height: 20), cornerSize: CGSize(width: 5, height: 5), style: .circular)
            path.addLine(to: CGPoint(x: sleepPoint.offsetX, y: sleepPoint.type))
                
            offsetX = sleepPoint.offsetX
            offsetY = sleepPoint.type
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

                Slider(
                    value: $speed,
                    in: startSleep.timeIntervalSince1970...endSleep.timeIntervalSince1970,
                    onEditingChanged: { editing in
                        isEditing = editing
                    }
                )
//                let _ = print(Date.init(timeIntervalSince1970: speed))
                Text("\((Date.init(timeIntervalSince1970: speed)), formatter: timeFormatter)")
                    .foregroundColor(isEditing ? .red : .blue).font(.caption)
            }


            HStack {
                ForEach(labels, id: \.id) { label in
                    if label.value == "x" {
                        Circle()
                            .fill(.gray)
                            .frame(width: 5, height: 5)
                    } else {
                        Text(label.value)
                            .font(.caption)
                    }
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
        .onChange(of: startSleep, perform: { value in
            speed = value.timeIntervalSince1970
        })
    }
}
