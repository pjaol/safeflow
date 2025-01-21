import SwiftUI

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView(cycleStore: cycleStore)
        }
    }
} 