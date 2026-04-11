import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var securityService: SecurityService
    @ObservedObject var cycleStore: CycleStore
    @Binding var hasCompletedOnboarding: Bool

    @State private var showingPinSetup = false
    @State private var currentPage = 0

    // Cycle setup state (page 3)
    @State private var lastPeriodDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    @State private var periodLength = 5
    @State private var cycleLength = 28

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                privacyPage.tag(0)
                trackingPage.tag(1)
                securityPage.tag(2)
                cycleSetupPage.tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .sheet(isPresented: $showingPinSetup) {
            PinSetupView()
                .interactiveDismissDisabled()
                .onDisappear {
                    Task {
                        if await securityService.hasFallbackPin {
                            withAnimation { currentPage = 3 }
                        }
                    }
                }
        }
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

    // MARK: - Page 1: Tracking

    private var trackingPage: some View {
        onboardingCard {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.secondaryPink)
                .iconCircle()
                .accessibilityHidden(true)

            Text("Know Your Cycle")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            Text("Log your period, symptoms, and mood. Clio Daye learns your pattern and shows you where you are in your cycle every day.")
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
                .accessibilityIdentifier("onboarding.pinButton")

                Button("Skip for Now") {
                    securityService.skipSecurity()
                    withAnimation { currentPage = 3 }
                }
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
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
                hasCompletedOnboarding = true
            }
            .font(AppTheme.Typography.captionFont)
            .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
        .tag(3)
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

// MARK: - Icon Circle helper

private extension View {
    func iconCircle() -> some View {
        self
            .padding()
            .background(Circle().fill(Color(UIColor.secondarySystemBackground)).shadow(radius: 2))
    }
}

#if DEBUG
#Preview {
    OnboardingView(
        cycleStore: CycleStore(),
        hasCompletedOnboarding: .constant(false)
    )
    .environmentObject(SecurityServicePreview.createPreview())
}
#endif
