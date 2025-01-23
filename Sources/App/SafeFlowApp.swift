import SwiftUI
import os

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "SafeFlowApp")
    
    // Create a StateObject wrapper class for SecurityService
    private class SecurityServiceWrapper: ObservableObject {
        @Published var service: SecurityService?
        
        init() {
            Task { @MainActor in
                let service = SecurityService()
                await service.configure()
                self.service = service
            }
        }
    }
    
    @StateObject private var securityWrapper = SecurityServiceWrapper()
    
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                Group {
                    if let securityService = securityWrapper.service {
                        mainContent(securityService: securityService, geometry: geometry)
                    } else {
                        ProgressView("Loading...")
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private func mainContent(securityService: SecurityService, geometry: GeometryProxy) -> some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(securityService)
            } else if securityService.isUnlocked {
                HomeView(cycleStore: cycleStore)
                    .environmentObject(securityService)
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
} 
