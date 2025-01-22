import SwiftUI
import os

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    @StateObject private var securityService = SecurityService()
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "SafeFlowApp")
    
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
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
                .onAppear {
                    logger.debug("Window size: \(geometry.size.width) x \(geometry.size.height)")
                    logger.debug("Safe area insets: top: \(geometry.safeAreaInsets.top), bottom: \(geometry.safeAreaInsets.bottom), left: \(geometry.safeAreaInsets.leading), right: \(geometry.safeAreaInsets.trailing)")
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    logger.debug("Window size changed to: \(newSize.width) x \(newSize.height)")
                }
            }
            .ignoresSafeArea()
        }
    }
} 
