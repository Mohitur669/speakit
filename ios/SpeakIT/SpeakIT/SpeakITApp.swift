//
//  SpeakITApp.swift
//  SpeakIT
//
//  Application entry point.
//

import SwiftUI

@main
struct SpeakITApp: App {
    @State private var appState = AppState.shared
    
    init() {
        if ProcessInfo.processInfo.arguments.contains("-runTests") {
            _ = SpeakITLogicTests.runAllTests()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
