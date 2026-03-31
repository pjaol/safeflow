import SwiftUI
import os

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @EnvironmentObject private var securityService: SecurityService

    @State private var showingLogSheet = false
    @State private var showingSettingsSheet = false
    @State private var dismissedNudgeIDs: Set<String> = DismissedNudges.load()
    @State private var dismissedSignalIDs: Set<String> = DismissedNudges.load()
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Metrics.standardSpacing) {

                    CyclePhaseCard(
                        phase: cycleStore.currentPhase(),
                        cycleDay: cycleStore.currentCycleDayNumber(),
                        predictionRange: cycleStore.predictNextPeriodRange(),
                        averageCycleLength: cycleStore.calculateAverageCycleLength(),
                        hasEnoughData: cycleStore.calculateAverageCycleLength() != nil
                    )

                    if let phase = cycleStore.currentPhase() {
                        PhaseTipCard(phase: phase)
                    }

                    if let insight = cycleStore.todayInsight() {
                        InsightCard(insight: insight)
                    }

                    ForEach(cycleStore.severitySignals()) { signal in
                        if !dismissedSignalIDs.contains(signal.id) {
                            SeveritySignalCard(signal: signal) {
                                DismissedNudges.dismiss(signal.id)
                                dismissedSignalIDs = DismissedNudges.load()
                            }
                        }
                    }

                    if let nudge = cycleStore.currentNudge() {
                        if !dismissedNudgeIDs.contains(nudge.id) {
                            PatternNudgeCard(nudge: nudge) {
                                DismissedNudges.dismiss(nudge.id)
                                dismissedNudgeIDs = DismissedNudges.load()
                            }
                        }
                    }

                    PulseView(cycleStore: cycleStore)
                        .frame(minHeight: 360)

                    ForecastView(cycleStore: cycleStore)

                    DailyLogCard(cycleDay: cycleStore.getCurrentDay())
                        .onTapGesture { showingLogSheet = true }
                        .accessibilityIdentifier("home.dailyLogCard")

                    CycleCalendarView(cycleStore: cycleStore)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("Clio Daye")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(AppTheme.Colors.secondaryPink)
                    }
                    .accessibilityIdentifier("home.debugButton")
                }
                #endif

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }
                    .accessibilityIdentifier("home.settingsButton")
                }

            }
            .sheet(isPresented: $showingLogSheet) {
                LogDayView(cycleStore: cycleStore, existingDay: cycleStore.getCurrentDay())
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
                    .environmentObject(securityService)
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenu(cycleStore: cycleStore)
            }
            #endif
        }
        .navigationViewStyle(.stack)
    }

}

// MARK: - Daily Log Card

struct DailyLogCard: View {
    let cycleDay: CycleDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            if let day = cycleDay {
                VStack(alignment: .leading, spacing: 8) {
                    if let flow = day.flow {
                        HStack(spacing: 6) {
                            Image(systemName: flow.sfSymbol)
                                .foregroundColor(AppTheme.Colors.secondaryPink)
                            Text("Flow: \(flow.localizedName)")
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                        }
                    }

                    if !day.symptoms.isEmpty {
                        Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let mood = day.mood {
                        HStack(spacing: 6) {
                            Image(systemName: mood.sfSymbol)
                                .foregroundColor(AppTheme.Colors.accentBlue)
                            Text("Mood: \(mood.localizedName)")
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                        }
                    }

                    if let notes = day.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(AppTheme.Typography.bodyFont)
            } else {
                Text("Tap to log your day")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Recent Logs Section

struct RecentLogsSection: View {
    let days: [CycleDay]
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)

            if days.isEmpty {
                Text("No recent logs")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            } else {
                ForEach(days) { day in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.date, style: .date)
                                .font(AppTheme.Typography.bodyFont)
                                .foregroundColor(AppTheme.Colors.deepGrayText)

                            if let flow = day.flow {
                                Label(flow.localizedName, systemImage: flow.sfSymbol)
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                            }

                            if !day.symptoms.isEmpty {
                                Text(day.symptoms.map { $0.localizedName }.joined(separator: ", "))
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer()

                        Button {
                            onDelete(day.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AppTheme.Colors.secondaryPink)
                        }
                        .accessibilityIdentifier("home.recentLog.delete.\(day.id)")
                    }
                    .padding()
                    .background(AppTheme.Colors.secondaryBackground)
                    .cornerRadius(AppTheme.Metrics.cornerRadius)
                }
            }
        }
    }
}
