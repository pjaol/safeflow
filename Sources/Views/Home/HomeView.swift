import SwiftUI
import os

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @EnvironmentObject private var securityService: SecurityService

    @State private var showingSettingsSheet = false
    @State private var dismissedNudgeIDs: Set<String> = DismissedNudges.load()
    @State private var dismissedSignalIDs: Set<String> = DismissedNudges.load()
    @State private var editLogsDate: Date? = nil
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Metrics.standardSpacing) {

                    // 1. Log first — zero scroll required
                    PulseView(cycleStore: cycleStore)
                        .frame(minHeight: 360)

                    // 2. Phase status
                    CyclePhaseCard(
                        phase: cycleStore.currentPhase(),
                        cycleDay: cycleStore.currentCycleDayNumber(),
                        predictionRange: cycleStore.predictNextPeriodRange(),
                        averageCycleLength: cycleStore.calculateAverageCycleLength(),
                        hasEnoughData: cycleStore.calculateAverageCycleLength() != nil
                    )

                    // 3. Edit historical logs
                    EditLogsButton { editLogsDate = Date() }

                    // 4–6. Conditional signal / nudge / insight cards
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

                    if let insight = cycleStore.todayInsight() {
                        InsightCard(insight: insight)
                    }

                    // 7. Phase tip
                    if let phase = cycleStore.currentPhase() {
                        PhaseTipCard(phase: phase)
                    }

                    // 8. Forecast
                    ForecastView(cycleStore: cycleStore)

                    // 9. History heat map
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
            .sheet(item: $editLogsDate) { date in
                EditLogsSheet(cycleStore: cycleStore, initialDate: date)
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

// MARK: - Edit Logs Button

private struct EditLogsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accentBlue)
                Text("Edit Logs")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accentBlue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
            .padding(.horizontal, AppTheme.Metrics.cardPadding)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.Metrics.cornerRadius)
        }
        .accessibilityIdentifier("home.editLogsButton")
    }
}

// MARK: - Edit Logs Sheet

private struct EditLogsSheet: View {
    let cycleStore: CycleStore
    @State private var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    init(cycleStore: CycleStore, initialDate: Date) {
        self.cycleStore = cycleStore
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker(
                    "Select date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .tint(AppTheme.Colors.accentBlue)

                Divider()

                LogDayView(
                    cycleStore: cycleStore,
                    existingDay: cycleStore.getDay(for: selectedDate),
                    targetDate: selectedDate
                )
            }
            .navigationTitle(selectedDate.formatted(.dateTime.month(.wide).day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
        }
    }
}
