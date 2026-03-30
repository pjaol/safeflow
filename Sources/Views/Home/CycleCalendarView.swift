import SwiftUI

// MARK: - CycleCalendarView

/// Multi-month history heat map using stacked sub-rows per variable.
///
/// Layout mirrors ForecastView exactly:
///   Y axis  — calendar months (3 or 6)
///   X axis  — 31 day columns, tick marks at 7/14/21
///
/// Each month row has three sub-rows:
///   A (flow)     — coral sequential luminance: spotting→heavy
///   B (symptoms) — purple sequential luminance: 1–2 / 3–5 / 6+
///   C (mood)     — 3-bucket hue: positive(teal) / neutral(amber) / negative(pink)
///
/// Predicted period/fertile window shown as dashed border on the flow sub-row,
/// same encoding as ForecastView.
struct CycleCalendarView: View {
    @ObservedObject var cycleStore: CycleStore
    @State private var monthCount = 3
    @State private var selectedMonth: Date?
    @State private var showingMonthDetail = false

    private let cal             = Calendar.current
    private let dayColumnCount  = 31
    private let monthLabelWidth: CGFloat = 34
    private let horizontalPad: CGFloat   = 16

    // Sub-row heights scale with mode — mirrors ForecastView proportions
    private var rowHeight: CGFloat  { monthCount == 3 ? 44 : 30 }
    private var subRowA: CGFloat    { monthCount == 3 ? 16 : 11 }  // flow
    private var subRowB: CGFloat    { monthCount == 3 ? 10 :  7 }  // symptoms
    private var subRowC: CGFloat    { monthCount == 3 ? 10 :  7 }  // mood
    private var subRowGap: CGFloat  { monthCount == 3 ?  4 :  2 }

    private var displayMonths: [Date] {
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        return (0..<monthCount).compactMap {
            cal.date(byAdding: .month, value: -$0, to: thisMonth)
        }.reversed()
    }

    private var forecasts: [CycleForecast] {
        cycleStore.forecastCycles(count: 6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            legendRow
                .padding(.horizontal, horizontalPad)
                .padding(.bottom, 6)
            GeometryReader { geo in
                let colWidth = (geo.size.width - monthLabelWidth - horizontalPad * 2) / CGFloat(dayColumnCount)
                VStack(spacing: 0) {
                    columnHeaderRow(colWidth: colWidth)
                        .padding(.bottom, 4)
                    monthRows(colWidth: colWidth)
                }
                .padding(.horizontal, horizontalPad)
            }
            .frame(height: gridHeight)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .sheet(isPresented: $showingMonthDetail) {
            if let month = selectedMonth {
                MonthSummaryView(cycleStore: cycleStore, month: month)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("History")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            Spacer()
            Picker("", selection: $monthCount) {
                Text("3 mo").tag(3)
                Text("6 mo").tag(6)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
        }
        .padding(.horizontal, horizontalPad)
        .padding(.vertical, 12)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 10) {
            legendChip(color: AppTheme.Colors.forecastPeriod,  label: "Flow")
            legendChip(color: AppTheme.Colors.forecastSymptom, label: "Symptoms")
            moodLegendChip()
            Spacer()
            legendChip(color: AppTheme.Colors.forecastPeriod.opacity(0.4), label: "Predicted", dashed: true)
        }
    }

    private func legendChip(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            if dashed {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 10, height: 10)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
    }

    /// Mood legend: three small squares showing the three buckets side-by-side
    private func moodLegendChip() -> some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2).fill(moodColor(.positive)).frame(width: 6, height: 10)
            RoundedRectangle(cornerRadius: 2).fill(moodColor(.neutral)).frame(width: 6, height: 10)
            RoundedRectangle(cornerRadius: 2).fill(moodColor(.negative)).frame(width: 6, height: 10)
            Text("Mood")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .padding(.leading, 2)
        }
    }

    // MARK: - Column headers

    private func columnHeaderRow(colWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: monthLabelWidth)
            ZStack(alignment: .leading) {
                ForEach([7, 14, 21], id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .frame(width: colWidth * 2, alignment: .center)
                        .offset(x: colWidth * CGFloat(day) - colWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 14)
    }

    // MARK: - Month rows

    private func monthRows(colWidth: CGFloat) -> some View {
        VStack(spacing: 6) {
            ForEach(displayMonths, id: \.self) { month in
                monthRow(month: month, colWidth: colWidth)
            }
        }
    }

    private func monthRow(month: Date, colWidth: CGFloat) -> some View {
        let monthStart  = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let daysInMonth = cal.range(of: .day, in: .month, for: month)!.count

        // Pre-compute per-column data once
        let columns: [(date: Date, day: CycleDay?)] = (0..<dayColumnCount).map { col in
            guard col < daysInMonth,
                  let date = cal.date(byAdding: .day, value: col, to: monthStart)
            else { return (Date.distantPast, nil) }
            return (date, cycleStore.getDay(for: date))
        }

        return HStack(spacing: 0) {
            Text(shortMonth(month))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(AppTheme.Colors.deepGrayText)
                .frame(width: monthLabelWidth, alignment: .leading)

            dayStrip(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth)
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMonth = month
            showingMonthDetail = true
        }
    }

    // MARK: - Day Strip

    private func dayStrip(
        columns: [(date: Date, day: CycleDay?)],
        daysInMonth: Int,
        colWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.background.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Week-boundary tick marks
            ForEach([7, 14, 21], id: \.self) { day in
                Rectangle()
                    .fill(AppTheme.Colors.mediumGrayText.opacity(0.15))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: colWidth * CGFloat(day))
            }

            VStack(spacing: subRowGap) {
                // Sub-row A: flow + prediction borders
                flowSubRow(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth)
                    .frame(height: subRowA)

                // Sub-row B: symptom burden
                symptomSubRow(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth)
                    .frame(height: subRowB)

                // Sub-row C: mood bucket
                moodSubRow(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth)
                    .frame(height: subRowC)
            }
            .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Sub-row A: Flow

    private func flowSubRow(
        columns: [(date: Date, day: CycleDay?)],
        daysInMonth: Int,
        colWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            // Logged flow cells
            ForEach(0..<dayColumnCount, id: \.self) { col in
                if col < daysInMonth {
                    let entry = columns[col]
                    if let flow = entry.day?.flow {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.Colors.forecastPeriod.opacity(flowOpacity(flow)))
                            .frame(width: max(1, colWidth - 1))
                            .offset(x: colWidth * CGFloat(col) + 0.5)
                    }
                }
            }

            // Today indicator
            ForEach(0..<dayColumnCount, id: \.self) { col in
                if col < daysInMonth {
                    let entry = columns[col]
                    if cal.isDateInToday(entry.date) {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AppTheme.Colors.accentBlue, lineWidth: 1.5)
                            .frame(width: max(1, colWidth - 1))
                            .offset(x: colWidth * CGFloat(col) + 0.5)
                    }
                }
            }

            // Predicted period — dashed border runs on logged (past) are skipped
            predictedRuns(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth,
                          color: AppTheme.Colors.forecastPeriod.opacity(0.5),
                          matches: { predictedPeriod($0) && $1 == nil })

            // Predicted fertile — dashed teal border
            predictedRuns(columns: columns, daysInMonth: daysInMonth, colWidth: colWidth,
                          color: AppTheme.Colors.forecastFertile.opacity(0.45),
                          matches: { predictedFertile($0) && $1 == nil })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    /// Renders contiguous runs of matching columns as dashed-border rectangles.
    private func predictedRuns(
        columns: [(date: Date, day: CycleDay?)],
        daysInMonth: Int,
        colWidth: CGFloat,
        color: Color,
        matches: (Date, CycleDay?) -> Bool
    ) -> some View {
        let matchCols = (0..<min(dayColumnCount, daysInMonth)).filter { col in
            matches(columns[col].date, columns[col].day)
        }
        let runs = consecutiveRuns(from: matchCols)

        return ZStack(alignment: .leading) {
            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                let x     = colWidth * CGFloat(run.first)
                let width = colWidth * CGFloat(run.last - run.first + 1) - 1
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .frame(width: max(colWidth, width))
                    .offset(x: x)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sub-row B: Symptom burden

    private func symptomSubRow(
        columns: [(date: Date, day: CycleDay?)],
        daysInMonth: Int,
        colWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<dayColumnCount, id: \.self) { col in
                if col < daysInMonth, let day = columns[col].day {
                    let count = day.symptoms.count
                    if count > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.Colors.forecastSymptom.opacity(symptomOpacity(count)))
                            .frame(width: max(1, colWidth - 1))
                            .offset(x: colWidth * CGFloat(col) + 0.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    // MARK: - Sub-row C: Mood bucket

    private func moodSubRow(
        columns: [(date: Date, day: CycleDay?)],
        daysInMonth: Int,
        colWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<dayColumnCount, id: \.self) { col in
                if col < daysInMonth, let mood = columns[col].day?.mood {
                    let bucket = moodBucket(mood)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(moodColor(bucket))
                        .frame(width: max(1, colWidth - 1))
                        .offset(x: colWidth * CGFloat(col) + 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    // MARK: - Encoding helpers

    private func flowOpacity(_ intensity: FlowIntensity) -> Double {
        switch intensity {
        case .spotting: return 0.25
        case .light:    return 0.50
        case .medium:   return 0.75
        case .heavy:    return 1.00
        }
    }

    private func symptomOpacity(_ count: Int) -> Double {
        switch count {
        case 1...2: return 0.35
        case 3...5: return 0.65
        default:    return 0.95  // 6+
        }
    }

    enum MoodBucket { case positive, neutral, negative }

    private func moodBucket(_ mood: Mood) -> MoodBucket {
        switch mood {
        case .energized, .happy, .confident, .calm, .focused: return .positive
        case .neutral:                                          return .neutral
        case .foggy, .tired, .sensitive, .anxious, .irritable, .sad: return .negative
        }
    }

    private func moodColor(_ bucket: MoodBucket) -> Color {
        switch bucket {
        case .positive: return AppTheme.Colors.forecastFertile.opacity(0.75)  // teal
        case .neutral:  return AppTheme.Colors.forecastMood.opacity(0.65)     // amber
        case .negative: return AppTheme.Colors.forecastSymptom.opacity(0.55)  // muted purple
        }
    }

    private func predictedPeriod(_ date: Date) -> Bool {
        forecasts.contains { $0.periodEarliest <= date && date <= $0.periodLatest }
    }

    private func predictedFertile(_ date: Date) -> Bool {
        forecasts.contains {
            guard let s = $0.fertileWindowStart, let e = $0.fertileWindowEnd else { return false }
            return s <= date && date <= e
        }
    }

    /// Groups sorted column indices into contiguous runs [(first, last)]
    private func consecutiveRuns(from ids: [Int]) -> [(first: Int, last: Int)] {
        guard !ids.isEmpty else { return [] }
        var runs: [(first: Int, last: Int)] = []
        var runStart = ids[0], runEnd = ids[0]
        for id in ids.dropFirst() {
            if id == runEnd + 1 { runEnd = id }
            else { runs.append((runStart, runEnd)); runStart = id; runEnd = id }
        }
        runs.append((runStart, runEnd))
        return runs
    }

    // MARK: - Layout helpers

    private var gridHeight: CGFloat {
        let headerH: CGFloat = 18
        let rows = CGFloat(monthCount)
        return rows * rowHeight + (rows - 1) * 6 + headerH
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

// MARK: - MonthSummaryView

struct MonthSummaryView: View {
    @ObservedObject var cycleStore: CycleStore
    let month: Date
    @Environment(\.dismiss) private var dismiss
    @State private var logDate: Date?
    @State private var showingLogSheet = false

    private let cal = Calendar.current

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    /// All days in this month that have a log entry, grouped into weeks (Mon–Sun).
    private var weekGroups: [(label: String, days: [(date: Date, day: CycleDay)])] {
        let monthStart  = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let daysInMonth = cal.range(of: .day, in: .month, for: month)!.count

        let logged: [(date: Date, day: CycleDay)] = (0..<daysInMonth).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: monthStart),
                  let day  = cycleStore.getDay(for: date) else { return nil }
            return (date, day)
        }

        var byWeek: [(weekStart: Date, days: [(date: Date, day: CycleDay)])] = []
        for entry in logged {
            let ws = weekMonday(for: entry.date)
            if let idx = byWeek.firstIndex(where: { cal.isDate($0.weekStart, inSameDayAs: ws) }) {
                byWeek[idx].days.append(entry)
            } else {
                byWeek.append((ws, [entry]))
            }
        }

        let startFmt = DateFormatter()
        startFmt.dateFormat = "MMM d"
        let endFmt = DateFormatter()
        return byWeek.map { group in
            let end = cal.date(byAdding: .day, value: 6, to: group.weekStart) ?? group.weekStart
            endFmt.dateFormat = cal.isDate(group.weekStart, equalTo: end, toGranularity: .month) ? "d" : "MMM d"
            let label = "\(startFmt.string(from: group.weekStart)) – \(endFmt.string(from: end))"
            return (label, group.days)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if weekGroups.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Nothing logged in \(monthLabel)")
                            .font(AppTheme.Typography.bodyFont)
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(weekGroups, id: \.label) { group in
                            Section(header: Text(group.label)) {
                                ForEach(group.days, id: \.date) { entry in
                                    WeekDayRow(date: entry.date, day: entry.day) {
                                        logDate = entry.date
                                        showingLogSheet = true
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(monthLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                if let date = logDate {
                    LogDayView(cycleStore: cycleStore, existingDay: cycleStore.getDay(for: date) ?? CycleDay(date: date, flow: nil))
                }
            }
        }
    }

    private func weekMonday(for date: Date) -> Date {
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2
        return cal.date(from: comps) ?? date
    }
}

// MARK: - WeekDayRow

private struct WeekDayRow: View {
    let date: Date
    let day: CycleDay
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                if let flow = day.flow {
                    HStack(spacing: 4) {
                        Text(flow.emoji).font(.caption)
                        Text(flow.localizedName)
                            .font(AppTheme.Typography.captionFont)
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }
                }
                if !day.symptoms.isEmpty {
                    SymptomChips(symptoms: Array(day.symptoms))
                }
                if let mood = day.mood {
                    HStack(spacing: 4) {
                        Text(mood.emoji).font(.caption)
                        Text(mood.localizedName)
                            .font(AppTheme.Typography.captionFont)
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                    }
                }
                if let notes = day.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTheme.Typography.captionFont)
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(AppTheme.Colors.accentBlue)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }
}

// MARK: - SymptomChips

private struct SymptomChips: View {
    let symptoms: [Symptom]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(symptoms.prefix(3), id: \.self) { symptom in
                Text(symptom.localizedName)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(AppTheme.Colors.forecastSymptom)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.forecastSymptom.opacity(0.12))
                    .cornerRadius(6)
            }
            if symptoms.count > 3 {
                Text("+\(symptoms.count - 3)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
    }
}

// MARK: - DayDetailView

struct DayDetailView: View {
    @ObservedObject var cycleStore: CycleStore
    let date: Date
    let existingDay: CycleDay?
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogSheet = false

    var body: some View {
        NavigationView {
            Group {
                if let day = existingDay {
                    List {
                        if let flow = day.flow {
                            Section {
                                Label("\(flow.emoji) \(flow.localizedName)", systemImage: "")
                                    .font(AppTheme.Typography.bodyFont)
                            } header: { Text("Flow") }
                        }
                        if !day.symptoms.isEmpty {
                            Section {
                                ForEach(Array(day.symptoms).sorted { $0.localizedName < $1.localizedName }, id: \.self) {
                                    Text($0.localizedName).font(AppTheme.Typography.bodyFont)
                                }
                            } header: { Text("Symptoms") }
                        }
                        if let mood = day.mood {
                            Section {
                                Label("\(mood.emoji) \(mood.localizedName)", systemImage: "")
                                    .font(AppTheme.Typography.bodyFont)
                            } header: { Text("Mood") }
                        }
                        if let notes = day.notes, !notes.isEmpty {
                            Section {
                                Text(notes).font(AppTheme.Typography.bodyFont)
                            } header: { Text("Notes") }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Nothing logged for this day")
                            .font(AppTheme.Typography.bodyFont)
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingLogSheet = true } label: {
                        Image(systemName: "pencil").foregroundColor(AppTheme.Colors.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogDayView(cycleStore: cycleStore, existingDay: existingDay ?? CycleDay(date: date, flow: nil))
            }
        }
    }
}
