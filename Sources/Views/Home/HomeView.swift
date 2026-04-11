import SwiftUI
import os

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @EnvironmentObject private var securityService: SecurityService

    @State private var showingSettingsSheet = false
    @State private var showingSupportSheet = false
    @State private var dismissedNudgeIDs: Set<String> = DismissedNudges.load()
    @State private var dismissedSignalIDs: Set<String> = DismissedNudges.load()
    @State private var editLogsDate: Date? = nil
    @State private var scrollToForecast = false
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    // Pre-compute active signals once so the body isn't calling @MainActor evaluator repeatedly
    private var activeSignals: [SeveritySignal] {
        cycleStore.severitySignals().filter { !dismissedSignalIDs.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppTheme.Metrics.standardSpacing) {

                        // ── Zone 1: Log today ────────────────────────────────
                        PulseView(cycleStore: cycleStore)
                            .frame(minHeight: 360)

                        // ── Zone 2: Cycle ring summary (phase + alerts + insights + tips) ──
                        CycleRingSummaryCard(
                            cycleStore: cycleStore,
                            phase: cycleStore.currentPhase(),
                            cycleDay: cycleStore.currentCycleDayNumber(),
                            predictionRange: cycleStore.predictNextPeriodRange(),
                            averageCycleLength: cycleStore.calculateAverageCycleLength(),
                            activeSignals: activeSignals,
                            activeNudge: { () -> CycleNudge? in
                                guard let nudge = cycleStore.currentNudge(),
                                      !dismissedNudgeIDs.contains(nudge.id) else { return nil }
                                return nudge
                            }(),
                            onDismissSignal: { id in
                                DismissedNudges.dismiss(id)
                                dismissedSignalIDs = DismissedNudges.load()
                            },
                            onDismissNudge: {
                                if let nudge = cycleStore.currentNudge() {
                                    DismissedNudges.dismiss(nudge.id)
                                    dismissedNudgeIDs = DismissedNudges.load()
                                }
                            }
                        )

                        // ── Zone 6: Data views ───────────────────────────────
                        ForecastView(cycleStore: cycleStore)
                            .id("forecast")

                        CycleCalendarView(cycleStore: cycleStore)
                            .id("history")
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
                .onChange(of: scrollToForecast) { _, _ in
                    withAnimation { proxy.scrollTo("forecast", anchor: .top) }
                }
            }
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
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("home.settingsButton")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        // Edit logs
                        Button {
                            editLogsDate = Date()
                        } label: {
                            Image(systemName: "doc.text")
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel("Edit logs")
                        .accessibilityIdentifier("home.editLogsButton")

                        // Jump to forecast
                        Button {
                            scrollToForecast.toggle()
                        } label: {
                            Image(systemName: "calendar")
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel("View forecast")
                        .accessibilityIdentifier("home.forecastButton")

                        // Get Support — always one tap away
                        Button {
                            showingSupportSheet = true
                        } label: {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.secondaryPink)
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel("Get Support — resources and helplines")
                        .accessibilityIdentifier("home.getSupportButton")
                    }
                }
            }
            .sheet(item: $editLogsDate) { date in
                EditLogsSheet(cycleStore: cycleStore, initialDate: date)
            }
            .sheet(isPresented: $showingSupportSheet) {
                GetSupportView(cycleStore: cycleStore)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView(cycleStore: cycleStore)
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
                    .accessibilityHidden(true)
                Text("Edit Logs")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accentBlue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppTheme.Metrics.cardPadding)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
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

    private var loggedDates: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(cycleStore.getAllDays().map { formatter.string(from: $0.date) })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Custom calendar with logged-day dots
                    LogCalendarView(
                        selectedDate: $selectedDate,
                        loggedDates: loggedDates
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.bottom, 8)

                    // Inline log form — re-initialises when date changes
                    LogDayFormView(
                        cycleStore: cycleStore,
                        targetDate: selectedDate,
                        existingDay: cycleStore.getDay(for: selectedDate)
                    )
                    .id(selectedDate)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(selectedDate.formatted(.dateTime.month(.abbreviated).day().year()))
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

// MARK: - Log Calendar View

/// A compact month calendar that shows dot indicators on days with logged data.
private struct LogCalendarView: View {
    @Binding var selectedDate: Date
    let loggedDates: Set<String>

    @State private var displayedMonth: Date

    private let cal = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols: [String] = {
        var syms = Calendar.current.veryShortWeekdaySymbols
        // Rotate so week starts on Monday (index 1 = Mon … 0 = Sun moves to end)
        let sun = syms.removeFirst(); syms.append(sun)
        return syms
    }()

    init(selectedDate: Binding<Date>, loggedDates: Set<String>) {
        _selectedDate = selectedDate
        self.loggedDates = loggedDates
        _displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    // All day cells for the displayed month grid (including leading/trailing blanks as nil)
    private var gridDays: [Date?] {
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
            let range = cal.range(of: .day, in: .month, for: displayedMonth)
        else { return [] }

        // Weekday of month start, shifted so Monday = 0
        var startWeekday = cal.component(.weekday, from: monthStart) - 2 // 0=Mon
        if startWeekday < 0 { startWeekday += 7 }

        var days: [Date?] = Array(repeating: nil, count: startWeekday)
        for d in 0..<range.count {
            days.append(cal.date(byAdding: .day, value: d, to: monthStart))
        }
        // Pad to full rows
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month nav header
            HStack {
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)

                Spacer()

                let isCurrentMonth = cal.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isCurrentMonth ? AppTheme.Colors.mediumGrayText.opacity(0.3) : AppTheme.Colors.accentBlue)
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Next month")
                .disabled(isCurrentMonth)
            }

            // Weekday labels
            LazyVGrid(columns: cols, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }
            }

            // Day cells
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                            isToday: cal.isDateInToday(date),
                            isFuture: date > Date(),
                            hasLog: loggedDates.contains(dayFormatter.string(from: date))
                        ) {
                            selectedDate = date
                            displayedMonth = date
                        }
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        .onChange(of: selectedDate) { _, newDate in
            // If the user picks a date via external means, sync the displayed month
            if !cal.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newDate
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let hasLog: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(.callout, design: .rounded, weight: isSelected || isToday ? .bold : .regular))
                    .foregroundColor(cellTextColor)
                    .frame(width: 34, height: 34)
                    .background(cellBackground)
                    .clipShape(Circle())

                // Log dot
                Circle()
                    .fill(hasLog ? logDotColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .disabled(isFuture)
        .frame(maxWidth: .infinity)
    }

    private var cellTextColor: Color {
        if isSelected { return .white }
        if isFuture { return AppTheme.Colors.mediumGrayText.opacity(0.35) }
        if isToday { return AppTheme.Colors.accentBlue }
        return AppTheme.Colors.deepGrayText
    }

    private var cellBackground: Color {
        if isSelected { return AppTheme.Colors.accentBlue }
        if isToday { return AppTheme.Colors.accentBlue.opacity(0.12) }
        return .clear
    }

    private var logDotColor: Color {
        isSelected ? .white.opacity(0.8) : AppTheme.Colors.accentBlue
    }
}

// MARK: - Log Day Form View (inline, no NavigationView)

/// The log form without its own NavigationView — embedded inside EditLogsSheet's scroll view.
private struct LogDayFormView: View {
    @ObservedObject var cycleStore: CycleStore
    let targetDate: Date
    let existingDay: CycleDay?

    @State private var selectedFlow: FlowIntensity?
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var selectedMood: Mood?
    @State private var notes: String = ""
    @State private var selectedSymptomCategory: SymptomCategory = .pain
    @State private var saved = false

    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LogDayFormView")

    init(cycleStore: CycleStore, targetDate: Date, existingDay: CycleDay?) {
        self.cycleStore = cycleStore
        self.targetDate = targetDate
        self.existingDay = existingDay
        _selectedFlow = State(initialValue: existingDay?.flow)
        _selectedSymptoms = State(initialValue: existingDay?.symptoms ?? [])
        _selectedMood = State(initialValue: existingDay?.mood)
        _notes = State(initialValue: existingDay?.notes ?? "")
    }

    var body: some View {
        VStack(spacing: AppTheme.Metrics.standardSpacing) {
            if existingDay != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                        .accessibilityHidden(true)
                    Text("Existing log — editing")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            flowSection
            symptomsSection
            moodSection
            notesSection

            Button(action: saveDay) {
                HStack(spacing: 8) {
                    Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .accessibilityHidden(true)
                    Text(saved ? "Saved" : (existingDay != nil ? "Update Log" : "Save Log"))
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(saved ? Color.green.opacity(0.8) : AppTheme.Colors.accentBlue)
                .cornerRadius(AppTheme.Metrics.buttonCornerRadius)
            }
            .animation(.easeInOut(duration: 0.2), value: saved)
        }
    }

    // MARK: - Sections (copied from LogDayView)

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Flow", systemImage: "drop.fill", color: AppTheme.Colors.secondaryPink)
            HStack(spacing: 10) {
                FlowChip(label: "None", sfSymbol: "xmark", isSelected: selectedFlow == nil,
                         color: AppTheme.Colors.neutralGray) { selectedFlow = nil }
                ForEach(FlowIntensity.allCases, id: \.self) { flow in
                    FlowChip(label: flow.localizedName, sfSymbol: flow.sfSymbol,
                             isSelected: selectedFlow == flow, color: AppTheme.Colors.secondaryPink) {
                        selectedFlow = flow
                    }
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Symptoms", systemImage: "heart.text.square", color: AppTheme.Colors.accentBlue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SymptomCategory.allCases, id: \.self) { category in
                        CategoryTab(label: category.localizedName,
                                    isSelected: selectedSymptomCategory == category) {
                            selectedSymptomCategory = category
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            let symptomsInCategory = Symptom.allCases.filter { $0.category == selectedSymptomCategory }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(symptomsInCategory, id: \.self) { symptom in
                    SymptomChip(symptom: symptom, isSelected: selectedSymptoms.contains(symptom)) {
                        if selectedSymptoms.contains(symptom) { selectedSymptoms.remove(symptom) }
                        else { selectedSymptoms.insert(symptom) }
                    }
                }
            }
            if !selectedSymptoms.isEmpty {
                Text("\(selectedSymptoms.count) selected")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Mood", systemImage: "face.smiling", color: AppTheme.Colors.forecastMood)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodCell(mood: mood, isSelected: selectedMood == mood) {
                        selectedMood = (selectedMood == mood) ? nil : mood
                    }
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notes", systemImage: "note.text", color: AppTheme.Colors.primaryBlue)
            TextEditor(text: $notes)
                .frame(minHeight: 88)
                .font(AppTheme.Typography.bodyFont)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundColor(color)
                .font(.system(.callout, weight: .semibold))
                .accessibilityHidden(true)
            Text(title).font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundColor(AppTheme.Colors.deepGrayText)
        }
    }

    private func saveDay() {
        let day = CycleDay(
            id: existingDay?.id ?? UUID(),
            date: targetDate,
            flow: selectedFlow,
            symptoms: selectedSymptoms,
            mood: selectedMood,
            notes: notes.isEmpty ? nil : notes
        )
        logger.debug("Saving day id:\(day.id.uuidString) date:\(day.date.description)")
        cycleStore.addOrUpdateDay(day)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
    }
}
