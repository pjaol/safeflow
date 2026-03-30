import SwiftUI
import os

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @EnvironmentObject private var securityService: SecurityService

    @State private var showingLogSheet = false
    @State private var showingNewEntrySheet = false
    @State private var showingSettingsSheet = false
    @State private var showingFlowSheet = false
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

                    QuickLogButtons(
                        currentDay: cycleStore.getCurrentDay(),
                        onPeriodStarted: { showingFlowSheet = true },
                        onStillFlowing: { logStillFlowing() },
                        onNoPeriod: { logNoPeriod() }
                    )

                    ForecastView(cycleStore: cycleStore)

                    DailyLogCard(cycleDay: cycleStore.getCurrentDay())
                        .onTapGesture { showingLogSheet = true }
                        .accessibilityIdentifier("home.dailyLogCard")

                    RecentLogsSection(days: cycleStore.recentDays) { id in
                        cycleStore.deleteDay(id: id)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("SafeFlow")
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntrySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                            .foregroundColor(AppTheme.Colors.primaryBlue)
                    }
                    .accessibilityIdentifier("home.newLogButton")
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogDayView(cycleStore: cycleStore, existingDay: cycleStore.getCurrentDay())
            }
            .sheet(isPresented: $showingNewEntrySheet) {
                LogDayView(cycleStore: cycleStore, existingDay: nil)
            }
            .sheet(isPresented: $showingFlowSheet) {
                QuickLogView(cycleStore: cycleStore)
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

    // MARK: - Quick Log Actions

    private func logStillFlowing() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastFlow = cycleStore.recentDays.first(where: { $0.flow != nil })?.flow ?? .medium
        let existing = cycleStore.getCurrentDay()
        let day = CycleDay(
            id: existing?.id ?? UUID(),
            date: existing?.date ?? today,
            flow: lastFlow,
            symptoms: existing?.symptoms ?? [],
            mood: existing?.mood,
            notes: existing?.notes
        )
        cycleStore.addOrUpdateDay(day)
    }

    private func logNoPeriod() {
        let today = Calendar.current.startOfDay(for: Date())
        guard cycleStore.getCurrentDay() == nil else { return }
        let day = CycleDay(date: today, flow: nil)
        cycleStore.addOrUpdateDay(day)
    }
}

// MARK: - Quick Log Buttons

private struct QuickLogButtons: View {
    let currentDay: CycleDay?
    let onPeriodStarted: () -> Void
    let onStillFlowing: () -> Void
    let onNoPeriod: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            QuickLogButton(
                label: "Period\nstarted",
                emoji: "🩸",
                color: AppTheme.Colors.secondaryPink,
                action: onPeriodStarted
            )
            .accessibilityIdentifier("home.quickLog.periodStarted")

            QuickLogButton(
                label: "Still\nflowing",
                emoji: "💧",
                color: AppTheme.Colors.primaryBlue,
                action: onStillFlowing
            )
            .accessibilityIdentifier("home.quickLog.stillFlowing")

            QuickLogButton(
                label: "No\nperiod",
                emoji: "✓",
                color: AppTheme.Colors.paleYellow,
                action: onNoPeriod
            )
            .accessibilityIdentifier("home.quickLog.noPeriod")
        }
    }
}

private struct QuickLogButton: View {
    let label: String
    let emoji: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 26))
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.25))
            .cornerRadius(AppTheme.Metrics.cornerRadius)
        }
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
                            Text(flow.emoji)
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
                            Text(mood.emoji)
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
                                Text("\(flow.emoji) \(flow.localizedName)")
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
