//
//  ContentView.swift
//  Sleepi
//
//  Created by Ionut Radu on 24.04.2022.
//

import SwiftUI
import HealthKit
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "ContentView"
)

struct ContentView: View {
    @State var currentDate: Date = Date()
    @State var loading: Bool = true
    @State var disableNextDayButton: Bool = true
    @AppStorage("bundleCompileDate") private var bundleCompileDate: Double = Date().timeIntervalSinceReferenceDate
    @StateObject var sleepManager: SleepManager = SleepManager(date: Date())
    @StateObject var sleepDetector: SleepDetector = SleepDetector()
    
    private func isFirstTimeRunning() -> Bool {
        var compileDate:Double
        {
            let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
            if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
               let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
               let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date
            { return infoDate.timeIntervalSinceReferenceDate }
            return Date().timeIntervalSinceReferenceDate
        }
        let result: Bool = Date(timeIntervalSinceReferenceDate: bundleCompileDate) == Date(timeIntervalSinceReferenceDate: compileDate) ? false : true
        self.bundleCompileDate = compileDate
        logger.log("bundleCompileDate: \(bundleCompileDate) - \(Date(timeIntervalSinceReferenceDate: bundleCompileDate)); compileDate: \(compileDate) - \(Date(timeIntervalSinceReferenceDate: compileDate)); firstTimeRunning = \(result)")
        return result
    }
    
    var body: some View {
        LoadingView(isShowing: .constant(loading)) {
            ScrollView {
                VStack {
                    Group {
                        DateBar(sleepManager: sleepManager, currentDate: $currentDate, disableNextDayButton: $disableNextDayButton)
        
                        StatsBar(sleepManager: sleepManager)
                        
                        if !sleepManager.nightSleeps.isEmpty {
                            VStack {
                                SleepChart(sleeps: sleepManager.nightSleeps)
                            }
                        }
                        
                        if !sleepManager.nightSleeps.isEmpty {
                            AwakeStatistics(sleepManager: sleepManager)
                            RemStatistics(sleepManager: sleepManager)
                            LightSleepStatistics(sleepManager: sleepManager)
                            DeepSleepStatistics(sleepManager: sleepManager)
                            NapStatistics(sleepManager: sleepManager)
                        }
                    }
                    .padding(10)
                    .foregroundColor(Color("TextColorPrim"))
                    .background(Color("BackgroundSec"))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color("BackgroundPrim"))
            .gesture(DragGesture(minimumDistance: 20.0, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < 0 {
                        if (Calendar.current.compare(Date(), to: currentDate, toGranularity: .day) == .orderedDescending) {
                            self.currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
                        }
                    } else {
                        self.currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                    }
                }
            )
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear(){
                Task.init {
                    if isFirstTimeRunning() {
                        try? await sleepDetector.whenFirstimeRunning()
                    }
                    try? await sleepDetector.performSleepDetection()
                    try? await sleepManager.refreshSleeps(date: currentDate)
                    loading = false
                }
            }
            .onChange(of: currentDate, perform: { value in
                if (Calendar.current.compare(Date(), to: value, toGranularity: .day) == .orderedDescending) {
                    self.disableNextDayButton = false
                } else {
                    self.disableNextDayButton = true
                }
                Task.init {
                    try await sleepManager.refreshSleeps(date: value)
                    loading = false
                }
            })
            .onAppCameToForeground {
                print("onAppCameToForeground")
                Task.init {
                    try await sleepDetector.performSleepDetection()
                    try await sleepManager.refreshSleeps(date: currentDate)
                }
            }
            .onAppWentToBackground {
                print("onAppWentToBackground")
            }
            .refreshable {
                Task {
                    try? await sleepDetector.performSleepDetection()
                    try? await sleepManager.refreshSleeps(date: currentDate)
                }

            }
        }
    }
}

extension View {
    func onAppCameToForeground(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            action()
        }
    }
    
    
    func onAppWentToBackground(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            action()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewInterfaceOrientation(.portrait)
            ContentView()
                .previewInterfaceOrientation(.portrait)
                .preferredColorScheme(.dark)

        }
    }
}
