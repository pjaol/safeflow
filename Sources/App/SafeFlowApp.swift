import SwiftUI
import os

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "SafeFlowApp")

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
            .onAppear { handleLaunchArguments() }
        }
    }

    @ViewBuilder
    private func mainContent(securityService: SecurityService, geometry: GeometryProxy) -> some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(
                    cycleStore: cycleStore,
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
                .environmentObject(securityService)
            } else if securityService.isUnlocked {
                HomeView(cycleStore: cycleStore)
                    .environmentObject(securityService)
                    .onDisappear { securityService.lock() }
            } else {
                LockView()
                    .environmentObject(securityService)
            }
        }
        .onAppear {
            logger.debug("Window size: \(geometry.size.width) x \(geometry.size.height)")
        }
        .onChange(of: geometry.size) { _, newValue in
            logger.debug("Window size changed to: \(newValue.width) x \(newValue.height)")
        }
    }

    private func handleLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("UI-Testing") || args.contains("RESET_DATA") {
            cycleStore.clearAllData()
        }

        if args.contains("RESET_ONBOARDING") || args.contains("UI-Testing") {
            hasCompletedOnboarding = false
        }
    }
}
