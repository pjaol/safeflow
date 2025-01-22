import SwiftUI

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    @StateObject private var securityService = SecurityService()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if securityService.isUnlocked {
                    HomeView(cycleStore: cycleStore)
                        .onDisappear {
                            securityService.lock()
                        }
                } else {
                    LockView()
                        .environmentObject(securityService)
                }
            }
            .ignoresSafeArea()
        }
    }
} 