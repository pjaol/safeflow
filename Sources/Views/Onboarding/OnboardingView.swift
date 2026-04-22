import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var securityService: SecurityService
    @ObservedObject var cycleStore: CycleStore
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(LifeStage.defaultsKey) private var persistedLifeStage: LifeStage = .regular
    @AppStorage(PausedContext.defaultsKey) private var persistedPausedContext: PausedContext = .notTracking

    @State private var showingPinSetup = false
    @State private var currentPage = 0

    // Page 1 state: life stage selection
    @State private var selectedLifeStage: LifeStage = .regular
    // Page 1b state: paused sub-context (shown only when selectedLifeStage == .paused)
    @State private var showingPausedContext = false
    @State private var selectedPausedContext: PausedContext = .notTracking

    // Cycle setup state (page 3)
    @State private var lastPeriodDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    @State private var periodLength = 5
    @State private var cycleLength = 28

    /// Total pages varies by life stage: regular/irregular/perimenopause = 4, menopause = 3, paused = 3
    private var totalPages: Int {
        switch selectedLifeStage {
        case .regular, .irregular, .perimenopause: return 4
        case .menopause, .paused: return 3
        }
    }

    /// True when page 3 (cycle setup) should be shown — not for menopause or paused.
    private var showsCycleSetupPage: Bool {
        selectedLifeStage != .menopause && selectedLifeStage != .paused
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                privacyPage.tag(0)
                lifeStagePickerPage.tag(1)
                securityPage.tag(2)
                if showsCycleSetupPage {
                    cycleSetupPage.tag(3)
                } else {
                    allSetPage.tag(3)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentPage) { _, page in
                UIAccessibility.post(
                    notification: .screenChanged,
                    argument: pageTitle(for: page)
                )
            }
        }
        .sheet(isPresented: $showingPinSetup) {
            PinSetupView()
                .interactiveDismissDisabled()
                .onDisappear {
                    Task {
                        if await securityService.hasFallbackPin {
                            advanceFromSecurity()
                        }
                    }
                }
        }
        .sheet(isPresented: $showingPausedContext) {
            PausedContextSheet(selected: $selectedPausedContext) {
                showingPausedContext = false
            }
            .presentationDetents([.medium])
        }
    }

    private func advanceFromSecurity() {
        withAnimation(reduceMotion ? nil : .default) { currentPage = 3 }
    }

    // MARK: - Page 0: Privacy

    private var privacyPage: some View {
        onboardingCard {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.accentBlue)
                .iconCircle()
                .accessibilityHidden(true)

            Text("Your Privacy First")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Clio Daye stores all your data on this device only. No cloud, no account, no servers. It is physically impossible for us to access your data.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .tag(0)
    }

    // MARK: - Page 1: What brings you here?

    private var lifeStagePickerPage: some View {
        onboardingCard {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.secondaryPink)
                .iconCircle()
                .accessibilityHidden(true)

            Text("What brings you here?")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Choose what best describes you — Clio Daye adapts to what matters most.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(LifeStage.allCases, id: \.self) { stage in
                    OnboardingStageCard(stage: stage, isSelected: selectedLifeStage == stage) {
                        selectedLifeStage = stage
                        if stage == .paused {
                            showingPausedContext = true
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Text("You can change this any time in Settings.")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
        }
        .tag(1)
    }

    // MARK: - Page 2: Security

    private var securityPage: some View {
        onboardingCard {
            Image(systemName: securityService.canUseBiometrics ? "faceid" : "key.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.secondaryPink)
                .iconCircle()
                .accessibilityHidden(true)

            Text("Secure Your Data")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Add a PIN or Face ID so only you can access Clio Daye.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: AppTheme.Metrics.standardSpacing) {
                if securityService.canUseBiometrics {
                    Button {
                        Task {
                            let success = await securityService.authenticateWithBiometrics()
                            if success {
                                securityService.isAuthenticationRequired = true
                                showingPinSetup = true
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "faceid")
                                .accessibilityHidden(true)
                            Text("Set Up Face ID / Touch ID")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint(String(localized: "Enables Face ID or Touch ID to lock the app"))
                    .accessibilityIdentifier("onboarding.biometricButton")
                }

                Button {
                    showingPinSetup = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .accessibilityHidden(true)
                        Text("Set Up PIN")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint(String(localized: "Creates a numeric PIN to lock the app"))
                .accessibilityIdentifier("onboarding.pinButton")

                Button("Skip for Now") {
                    securityService.skipSecurity()
                    advanceFromSecurity()
                }
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
                .accessibilityHint(String(localized: "You can enable lock protection later in Settings"))
                .accessibilityIdentifier("onboarding.skipSecurityButton")
            }
            .padding(.horizontal, 40)
            .padding(.top, AppTheme.Metrics.standardSpacing)
        }
        .tag(2)
    }

    // MARK: - Page 3: Cycle Setup

    private var cycleSetupPage: some View {
        onboardingCard {
            Image(systemName: "drop.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.secondaryPink)
                .iconCircle()
                .accessibilityHidden(true)

            Text("Set Up Your Cycle")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Tell us a little about your cycle so predictions start right away.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Last period date
                VStack(alignment: .leading, spacing: 6) {
                    Text("When did your last period start?")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)

                    DatePicker(
                        "",
                        selection: $lastPeriodDate,
                        in: (Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date())...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("Last period start date")
                    .accessibilityHint("Select the date your most recent period began")
                    .accessibilityIdentifier("onboarding.lastPeriodDatePicker")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.Metrics.cornerRadius)

                // Period length
                VStack(alignment: .leading, spacing: 6) {
                    Text("How long does your period last?")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)

                    HStack {
                        Text("\(periodLength) days")
                            .font(AppTheme.Typography.bodyFont)
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .frame(width: 72, alignment: .leading)
                        Stepper("", value: $periodLength, in: 2...10)
                            .labelsHidden()
                            .accessibilityLabel("Period length, \(periodLength) days")
                            .accessibilityHint("Adjust how many days your period typically lasts")
                            .accessibilityIdentifier("onboarding.periodLengthStepper")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.Metrics.cornerRadius)

                // Cycle length
                VStack(alignment: .leading, spacing: 6) {
                    Text("How long is your cycle usually?")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                    Text("Day 1 of one period to Day 1 of the next")
                        .font(AppTheme.Typography.captionFont)
                        .foregroundColor(AppTheme.Colors.mediumGrayText)

                    HStack {
                        Text("\(cycleLength) days")
                            .font(AppTheme.Typography.bodyFont)
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .frame(width: 72, alignment: .leading)
                        Stepper("", value: $cycleLength, in: 15...60)
                            .labelsHidden()
                            .accessibilityLabel("Cycle length, \(cycleLength) days")
                            .accessibilityHint("Adjust the number of days from the start of one period to the start of the next")
                            .accessibilityIdentifier("onboarding.cycleLengthStepper")
                    }
                    Text("Not sure? Leave at 28 — we'll personalise this over time.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.Metrics.cornerRadius)
            }
            .padding(.horizontal, 8)
            .padding(.top, AppTheme.Metrics.standardSpacing)

            Button("Get Started") {
                persistedLifeStage = selectedLifeStage
                persistedPausedContext = selectedPausedContext
                let seed = CycleSeedData(
                    lastPeriodStartDate: lastPeriodDate,
                    typicalPeriodLength: periodLength,
                    typicalCycleLength: cycleLength
                )
                cycleStore.saveSeedData(seed)
                Task {
                    await NotificationService.shared.requestAuthorization()
                    cycleStore.rescheduleSupplyReminder()
                }
                hasCompletedOnboarding = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .accessibilityIdentifier("onboarding.getStartedButton")

            Button("Skip setup") {
                persistedLifeStage = selectedLifeStage
                persistedPausedContext = selectedPausedContext
                hasCompletedOnboarding = true
            }
            .font(AppTheme.Typography.captionFont)
            .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
        .tag(3)
    }

    // MARK: - Page 3b: All Set (menopause / paused — no cycle setup needed)

    private var allSetPage: some View {
        onboardingCard {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.accentBlue)
                .iconCircle()
                .accessibilityHidden(true)

            Text("You're all set")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Clio Daye is ready. Log how you feel each day and track what matters to you.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Let's Go") {
                persistedLifeStage = selectedLifeStage
                persistedPausedContext = selectedPausedContext
                hasCompletedOnboarding = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .accessibilityIdentifier("onboarding.letsGoButton")
        }
        .tag(3)
    }

    // MARK: - Accessibility helpers

    private func pageTitle(for page: Int) -> String {
        let total = totalPages
        switch page {
        case 0: return String(localized: "Your Privacy First, page 1 of \(total)")
        case 1: return String(localized: "What brings you here, page 2 of \(total)")
        case 2: return String(localized: "Secure Your Data, page 3 of \(total)")
        case 3:
            if showsCycleSetupPage {
                return String(localized: "Set Up Your Cycle, page 4 of \(total)")
            } else {
                return String(localized: "You're all set, page 4 of \(total)")
            }
        default: return "Onboarding"
        }
    }

    // MARK: - Card helper

    @ViewBuilder
    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Metrics.standardSpacing) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(radius: 2)
            )
            .padding()
        }
    }
}

// MARK: - OnboardingStageCard

private struct OnboardingStageCard: View {
    let stage: LifeStage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppTheme.Colors.secondaryPink : AppTheme.Colors.mediumGrayText.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.secondaryPink)
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.localizedName)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.deepGrayText)
                    Text(stage.settingsDescription)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                    .fill(isSelected
                          ? AppTheme.Colors.secondaryPink.opacity(0.08)
                          : AppTheme.Colors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                            .strokeBorder(isSelected ? AppTheme.Colors.secondaryPink.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stage.localizedNameString): \(stage.settingsDescriptionString)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.lifeStageCard.\(stage.rawValue)")
    }
}

// MARK: - PausedContextSheet

private struct PausedContextSheet: View {
    @Binding var selected: PausedContext
    let onDone: () -> Void

    @State private var hasChosen = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("A little more detail helps us set the right tone.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
                    .padding(.horizontal)
                    .padding(.top, 4)

                VStack(spacing: 8) {
                    PausedContextRow(context: .recovering, isSelected: selected == .recovering && hasChosen) {
                        selected = .recovering
                        hasChosen = true
                    }
                    PausedContextRow(context: .notTracking, isSelected: selected == .notTracking && hasChosen) {
                        selected = .notTracking
                        hasChosen = true
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Why are you pausing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasChosen ? "Done" : "Skip", action: onDone)
                        .foregroundStyle(AppTheme.Colors.primaryBlue)
                }
            }
        }
    }
}

private struct PausedContextRow: View {
    let context: PausedContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppTheme.Colors.primaryBlue : AppTheme.Colors.mediumGrayText.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(AppTheme.Colors.primaryBlue).frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                Text(context.localizedName)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                    .fill(isSelected
                          ? AppTheme.Colors.primaryBlue.opacity(0.08)
                          : AppTheme.Colors.secondaryBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(context.localizedNameString)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.pausedContext.\(context.rawValue)")
    }
}

// MARK: - Icon Circle helper

private extension View {
    func iconCircle() -> some View {
        self
            .padding()
            .background(Circle().fill(Color(UIColor.secondarySystemBackground)).shadow(radius: 2))
    }
}

#if DEBUG || BETA
#Preview {
    OnboardingView(
        cycleStore: CycleStore(),
        hasCompletedOnboarding: .constant(false)
    )
    .environmentObject(SecurityServicePreview.createPreview())
}
#endif
