import SwiftUI
import os

@main
struct SafeFlowApp: App {
    @StateObject private var cycleStore = CycleStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appLanguage") private var appLanguage: String = "system"
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

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("UI-Testing") {
            UserDefaults.standard.set(false, forKey: "isAuthenticationRequired")
        }
        // SNAPSHOT_LANGUAGE env var (set by the test via app.launchEnvironment) controls
        // the SwiftUI locale for snapshots. This must be applied before the first render.
        if let lang = ProcessInfo.processInfo.environment["SNAPSHOT_LANGUAGE"], !lang.isEmpty {
            UserDefaults.standard.set(lang, forKey: "appLanguage")
        } else if args.contains("UI-Testing") {
            // No explicit language: clear persisted value so .current locale takes effect.
            UserDefaults.standard.removeObject(forKey: "appLanguage")
        }
        // SKIP_ONBOARDING must be applied before the first render so the home
        // screen is shown immediately — onAppear fires too late for UI tests.
        if args.contains("SKIP_ONBOARDING") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } else if args.contains("UI-Testing") || args.contains("RESET_ONBOARDING") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        #endif
    }

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
            #if DEBUG || BETA
            .environment(\.locale, appLanguage == "system" || appLanguage.isEmpty ? .current : Locale(identifier: appLanguage))
            #endif
            .onAppear { handleLaunchArguments() }
            // #if DEBUG || BETA
            // .overlay(alignment: .bottom) { localeDebugBanner }
            // #endif
        }
    }

    // #if DEBUG || BETA
    // private var localeDebugBanner: some View {
    //     let resolvedLocale = Locale(identifier: appLanguage.isEmpty ? "en" : appLanguage)
    //     let osLanguages = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.prefix(2).joined(separator: ", ") ?? "?"
    //     let osLocale = UserDefaults.standard.string(forKey: "AppleLocale") ?? Locale.current.identifier
    //
    //     return VStack(spacing: 2) {
    //         Text("appLanguage: \"\(appLanguage)\" → \(resolvedLocale.identifier)")
    //         Text("OS AppleLanguages: \(osLanguages)")
    //         Text("OS AppleLocale: \(osLocale)")
    //         Text("Bundle locale: \(Bundle.main.preferredLocalizations.first ?? "?")")
    //     }
    //     .font(.system(size: 10, design: .monospaced))
    //     .foregroundColor(.white)
    //     .padding(.horizontal, 8)
    //     .padding(.vertical, 4)
    //     .background(Color.black.opacity(0.75))
    //     .padding(.bottom, 8)
    // }
    // #endif

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
        #if DEBUG || BETA
        let args = ProcessInfo.processInfo.arguments

        if args.contains("UI-Testing") || args.contains("RESET_DATA") {
            cycleStore.clearAllData()
        }

        if args.contains("LOAD_SYMPTOM_RICH") {
            loadTestScenario(filename: "symptom_rich_cycles", cycleLength: 28, periodLength: 6)
        }
        #endif
    }

    #if DEBUG || BETA
    private func loadTestScenario(filename: String, cycleLength: Int, periodLength: Int) {
        Task {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "csv"),
                  let csv = try? String(contentsOf: url, encoding: .utf8),
                  let entries = try? TestDataLoader.shared.parseEntriesPublic(from: csv),
                  let firstEntry = entries.first else { return }

            let seed = CycleSeedData(
                lastPeriodStartDate: firstEntry.date,
                typicalPeriodLength: periodLength,
                typicalCycleLength: cycleLength
            )
            cycleStore.saveSeedData(seed)
            for entry in entries {
                cycleStore.addOrUpdateDay(CycleDay(
                    id: UUID(),
                    date: entry.date,
                    flow: entry.flow,
                    symptoms: entry.symptoms,
                    mood: entry.mood,
                    notes: entry.notes
                ))
            }
        }
    }
    #endif
}
