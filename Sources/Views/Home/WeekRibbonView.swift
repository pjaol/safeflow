import SwiftUI

// MARK: - DimensionScore
//
// A day scored into 5 bidirectional dimensions.
// Positive values go above the centerline, negative below.
// Range: -1.0 … +1.0 per dimension.

struct DimensionScore {
    let date: Date
    let day: CycleDay?

    // Negative (below centerline)
    var flow: Double    // 0 … -1   (none → heavy)
    var pain: Double    // 0 … -1   (symptom count 0–6 normalised)
    var body: Double    // 0 … -1   (symptom count 0–5 normalised)
    var fatigue: Double // 0 … -1   (fatigue / fog / insomnia)

    // Bidirectional
    var mood: Double    // -1 … +1  (negative moods → -1, positive → +1)
    var energy: Double  // -1 … +1  (highEnergy → +1, fatigue overlap handled)

    static func score(date: Date, day: CycleDay?) -> DimensionScore {
        guard let day else {
            return DimensionScore(date: date, day: nil,
                                  flow: 0, pain: 0, body: 0, fatigue: 0,
                                  mood: 0, energy: 0)
        }

        // Flow: spotting=0.25, light=0.5, medium=0.75, heavy=1.0
        let flowScore: Double = {
            switch day.flow {
            case .spotting: return -0.25
            case .light:    return -0.50
            case .medium:   return -0.75
            case .heavy:    return -1.00
            case nil:       return  0.00
            }
        }()

        // Pain: cramps, headache, bloating, breastTenderness, backPain, mittelschmerz
        let painSymptoms: Set<Symptom> = [.cramps, .headache, .bloating, .breastTenderness, .backPain, .mittelschmerz]
        let painCount = Double(day.symptoms.intersection(painSymptoms).count)
        let painScore = -(painCount / 6.0)

        // Body: foodCravings, nausea, appetiteChanges, acne, dischargeChanges
        let bodySymptoms: Set<Symptom> = [.foodCravings, .nausea, .appetiteChanges, .acne, .dischargeChanges]
        let bodyCount = Double(day.symptoms.intersection(bodySymptoms).count)
        let bodyScore = -(bodyCount / 5.0)

        // Fatigue: fatigue, insomnia, brainFog (negative energy)
        let fatigueSymptoms: Set<Symptom> = [.fatigue, .insomnia, .brainFog]
        let fatigueCount = Double(day.symptoms.intersection(fatigueSymptoms).count)
        let fatigueScore = -(fatigueCount / 3.0)

        // Energy: highEnergy is positive
        let energyScore: Double = day.symptoms.contains(.highEnergy) ? 0.8 : 0

        // Mood: map to -1…+1
        let moodScore: Double = {
            guard let mood = day.mood else { return 0 }
            switch mood {
            case .energized:  return  1.0
            case .happy:      return  0.85
            case .confident:  return  0.75
            case .calm:       return  0.65
            case .focused:    return  0.55
            case .neutral:    return  0.0
            case .foggy:      return -0.4
            case .tired:      return -0.5
            case .sensitive:  return -0.55
            case .anxious:    return -0.7
            case .irritable:  return -0.8
            case .sad:        return -1.0
            }
        }()

        return DimensionScore(
            date:    date,
            day:     day,
            flow:    flowScore,
            pain:    painScore,
            body:    bodyScore,
            fatigue: fatigueScore,
            mood:    moodScore,
            energy:  energyScore
        )
    }
}

// MARK: - ChartRange

enum ChartRange: String, CaseIterable {
    case week  = "1W"
    case month = "1M"
    case threeMonth = "3M"

    var label: LocalizedStringKey {
        switch self {
        case .week:       return "1W"
        case .month:      return "1M"
        case .threeMonth: return "3M"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .week:       return "week"
        case .month:      return "month"
        case .threeMonth: return "3 months"
        }
    }

    var columnCount: Int {
        switch self {
        case .week:       return 7
        case .month:      return 30
        case .threeMonth: return 91
        }
    }

    /// True when individual day tap targets are practical
    var supportsDayTap: Bool { self == .week }
}

// MARK: - WeekRibbonView

struct WeekRibbonView: View {
    @ObservedObject var cycleStore: CycleStore
    let initialWeek: Date   // any date within the week to show first

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var range: ChartRange = .week
    /// Offset in units of `range` from the anchor date
    @State private var pageOffset: Int = 0
    @State private var selectedDate: Date?
    @State private var currentScores: [DimensionScore] = []
    /// Accumulated drag translation, in screen points
    @State private var dragOffset: CGFloat = 0
    /// Width of the chart canvas (minus Y-axis strip) — set via GeometryReader
    @State private var chartCanvasWidth: CGFloat = 300
    @State private var showingAccessibleChart = false

    private let cal = Calendar.current

    // MARK: - Date window

    /// The first date of the currently displayed window.
    private func windowStart() -> Date {
        let anchor: Date
        switch range {
        case .week:
            anchor = weekMonday(for: initialWeek)
            return cal.date(byAdding: .weekOfYear, value: pageOffset, to: anchor) ?? anchor
        case .month:
            anchor = monthStart(for: initialWeek)
            return cal.date(byAdding: .month, value: pageOffset, to: anchor) ?? anchor
        case .threeMonth:
            anchor = monthStart(for: initialWeek)
            // Each page = 3 months
            return cal.date(byAdding: .month, value: pageOffset * 3, to: anchor) ?? anchor
        }
    }

    private func windowDates() -> [Date] {
        let start = windowStart()
        return (0..<range.columnCount).compactMap {
            cal.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func buildScores() -> [DimensionScore] {
        windowDates().map { date in
            DimensionScore.score(date: date, day: cycleStore.getDay(for: date))
        }
    }

    private var windowLabel: String {
        let dates = windowDates()
        guard let first = dates.first, let last = dates.last else { return "" }
        let sameMonth = cal.isDate(first, equalTo: last, toGranularity: .month)
        let sf = DateFormatter(); sf.locale = locale
        sf.setLocalizedDateFormatFromTemplate("MMMd")
        let ef = DateFormatter(); ef.locale = locale
        ef.setLocalizedDateFormatFromTemplate(sameMonth ? "d" : "MMMd")
        return "\(sf.string(from: first)) – \(ef.string(from: last))"
    }

    private var isAtCurrentWindow: Bool {
        let today = Date()
        switch range {
        case .week:
            return windowStart() >= weekMonday(for: today)
        case .month:
            return windowStart() >= monthStart(for: today)
        case .threeMonth:
            let base = monthStart(for: initialWeek)
            let currentWindow = cal.date(byAdding: .month, value: pageOffset * 3, to: base) ?? base
            let currentMonthStart = monthStart(for: today)
            return currentWindow >= currentMonthStart
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Range picker
                Picker("Chart range", selection: $range) {
                    ForEach(ChartRange.allCases, id: \.self) { r in
                        Text(r.label).tag(r)
                            .accessibilityLabel(r.accessibilityLabel)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .accessibilityHint(String(localized: "Select 1 week, 1 month, or 3 months"))
                .onChange(of: range) { pageOffset = 0 }

                // Nav bar
                navBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                // Chart area
                ZStack {
                    chartArea
                        .accessibilityHidden(!range.supportsDayTap)

                    if !range.supportsDayTap {
                        // Invisible prose summary for VoiceOver in month/3M mode
                        Text(chartAccessibilitySummary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(0)
                            .accessibilityLabel(chartAccessibilitySummary)
                            .accessibilityAction(named: "Show chart as list") {
                                showingAccessibleChart = true
                            }
                    }
                }
                .padding(.horizontal, 16)
                .id("\(range)-\(pageOffset)")

                // Tap hint
                Group {
                    if range.supportsDayTap {
                        Text("Tap a date for details")
                    } else {
                        Label("Tap chart to zoom into that week", systemImage: "magnifyingglass")
                    }
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color(.tertiaryLabel))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                // Legend
                ribbonLegend
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Week View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { currentScores = buildScores() }
            .onChange(of: pageOffset) { currentScores = buildScores() }
            .onChange(of: range) { currentScores = buildScores() }
            .sheet(isPresented: $showingAccessibleChart) {
                RibbonSummarySheet(scores: currentScores, windowLabel: windowLabel)
            }
            .sheet(item: $selectedDate) { date in
                DayDetailCard(
                    date: date,
                    day: cycleStore.getDay(for: date),
                    cycleStore: cycleStore
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Chart area

    private var chartArea: some View {
        ZStack(alignment: .bottom) {
            // Y-axis strip — decorative; semantic data is in day button labels
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("+")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(RibbonDimension.mood.color)
                    Spacer()
                    Text("Neutral")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                    Spacer()
                    Text("−")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(RibbonDimension.pain.color)
                }
                .frame(width: 36, height: 210)
                .padding(.bottom, range.supportsDayTap ? 50 : 24)
                .accessibilityHidden(true)
                Spacer()
            }

            // Ribbon chart — swipe left/right to navigate
            RibbonChart(
                scores: currentScores,
                onDayTap: range.supportsDayTap ? { date in selectedDate = date } : nil
            )
            .padding(.leading, 36)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { chartCanvasWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in chartCanvasWidth = newValue }
                }
            )
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { v in
                        dragOffset = v.translation.width * 0.35
                    }
                    .onEnded { v in
                        let threshold: CGFloat = 40
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                        if v.translation.width < -threshold {
                            if !isAtCurrentWindow { pageOffset += 1 }
                        } else if v.translation.width > threshold {
                            pageOffset -= 1
                        }
                    }
            )
            // 1M / 3M: tap anywhere to zoom into that week
            .overlay(
                Group {
                    if !range.supportsDayTap {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                // chartCanvasWidth includes the 36pt Y-axis strip.
                                // location.x=0 is the left edge of the strip, so the
                                // actual chart canvas starts at x=36.
                                let yAxisWidth: CGFloat = 36
                                let chartW = chartCanvasWidth - yAxisWidth
                                let adjustedX = location.x - yAxisWidth
                                guard adjustedX >= 0, chartW > 0 else { return }
                                let colW = chartW / CGFloat(range.columnCount)
                                let col = max(0, min(range.columnCount - 1,
                                                     Int(adjustedX / colW)))
                                let dates = windowDates()
                                if col < dates.count {
                                    zoomToWeek(containing: dates[col])
                                }
                            }
                    }
                }
            )
            .clipped()

            // Day labels + tap targets (week only)
            if range.supportsDayTap {
                HStack(spacing: 0) {
                    ForEach(Array(windowDates().enumerated()), id: \.offset) { idx, date in
                        Button { selectedDate = date } label: {
                            VStack(spacing: 2) {
                                Spacer()
                                Text(dayAbbrev(date))
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .accessibilityHidden(true)
                                Text("\(cal.component(.day, from: date))")
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(
                                        cal.isDateInToday(date)
                                        ? AppTheme.Colors.primaryBlue
                                        : AppTheme.Colors.deepGrayText
                                    )
                                    .accessibilityHidden(true)
                                Circle()
                                    .fill(cal.isDateInToday(date)
                                          ? AppTheme.Colors.primaryBlue
                                          : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dayAccessibilityLabel(for: date, scores: currentScores))
                        .accessibilityHint("Tap to see details for this day")
                    }
                }
                .padding(.leading, 36)
                .frame(height: 50)
            } else {
                // Month / 3M: show compact day-number ticks below chart
                GeometryReader { geo in
                    let chartW = geo.size.width - 36
                    let colW = chartW / CGFloat(range.columnCount)
                    ZStack(alignment: .leading) {
                        ForEach(Array(windowDates().enumerated()), id: \.offset) { idx, date in
                            let day = cal.component(.day, from: date)
                            if day == 1 || day % (range == .month ? 7 : 14) == 0 {
                                Text(day == 1
                                     ? monthAbbrev(date)
                                     : "\(day)")
                                    .font(.system(.caption2, design: .rounded).weight(.medium))
                                    .foregroundStyle(day == 1
                                                     ? AppTheme.Colors.deepGrayText
                                                     : Color(.tertiaryLabel))
                                    .offset(x: 36 + colW * CGFloat(idx))
                            }
                        }
                    }
                }
                .frame(height: 16)
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button { pageOffset -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryBlue)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Previous \(range.accessibilityLabel)")
            Spacer()
            Text(windowLabel)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepGrayText)
                .id("\(range)-\(pageOffset)")
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { pageOffset += 1 } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(isAtCurrentWindow
                                     ? Color(.tertiaryLabel)
                                     : AppTheme.Colors.primaryBlue)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Next \(range.accessibilityLabel)")
            .disabled(isAtCurrentWindow)
        }
    }

    // MARK: - Legend

    private var ribbonLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reading the chart")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(RibbonDimension.mood.color)
                    Text("positive")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color(.tertiaryLabel))
                    Text("·")
                        .foregroundStyle(Color(.tertiaryLabel))
                    Image(systemName: "arrow.down")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(RibbonDimension.pain.color)
                    Text("negative")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(RibbonDimension.allCases, id: \.self) { dim in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dim.color.opacity(0.75))
                            .frame(width: 24, height: 8)
                            .accessibilityHidden(true)
                        Text(dim.label)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // Period marker legend
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(RibbonDimension.flow.color)
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(RibbonDimension.flow.color.opacity(0.5))
                        .frame(width: 14, height: 1.5)
                    Circle()
                        .fill(RibbonDimension.flow.color.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                Text("Period start · end")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.secondaryBackground)
        )
    }

    // MARK: - Helpers

    /// Switches to 1W range and sets pageOffset so the week containing `date` is shown.
    private func zoomToWeek(containing date: Date) {
        let anchor = weekMonday(for: initialWeek)
        let target = weekMonday(for: date)
        let weeks = cal.dateComponents([.weekOfYear], from: anchor, to: target).weekOfYear ?? 0
        // Set state first — onChange(of: pageOffset) will rebuild scores
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            range = .week
            pageOffset = weeks
        }
    }

    private func weekMonday(for date: Date) -> Date {
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2
        return cal.date(from: comps) ?? date
    }

    private func monthStart(for date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = locale
        return f.string(from: date).uppercased()
    }

    private func monthAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"; f.locale = locale
        return f.string(from: date)
    }

    // MARK: - Accessibility helpers

    /// Enriched label for a single day button in week mode: date + key dimension highlights.
    private func dayAccessibilityLabel(for date: Date, scores: [DimensionScore]) -> String {
        let datePart = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let todayPrefix = cal.isDateInToday(date) ? String(localized: "Today, ") : ""
        guard let score = scores.first(where: { cal.isDate($0.date, inSameDayAs: date) }),
              score.day != nil else {
            return todayPrefix + datePart + ", no log"
        }
        var parts: [String] = [todayPrefix + datePart]
        if score.flow < -0.1 {
            let label = score.flow <= -0.75 ? "heavy flow" : score.flow <= -0.5 ? "medium flow" : score.flow <= -0.25 ? "light flow" : "spotting"
            parts.append(label)
        }
        if score.pain < -0.3 { parts.append("pain") }
        if score.fatigue < -0.3 { parts.append("fatigue") }
        if score.mood >= 0.5 { parts.append("positive mood") }
        else if score.mood <= -0.5 { parts.append("low mood") }
        return parts.joined(separator: ", ")
    }

    /// Prose summary of the current window's scores for VoiceOver in month/3M mode.
    private var chartAccessibilitySummary: String {
        let dates = windowDates()
        guard !currentScores.isEmpty else {
            return "\(windowLabel). No data logged in this period."
        }
        let logged = currentScores.filter { $0.day != nil }
        guard !logged.isEmpty else {
            return "\(windowLabel). No days logged."
        }
        let flowDays   = logged.filter { $0.flow < -0.1 }.count
        let painDays   = logged.filter { $0.pain < -0.3 }.count
        let fatigueDays = logged.filter { $0.fatigue < -0.3 }.count
        let positiveDays = logged.filter { $0.mood >= 0.5 }.count
        let lowMoodDays  = logged.filter { $0.mood <= -0.5 }.count

        var parts: [String] = ["\(windowLabel)."]
        parts.append("\(logged.count) of \(dates.count) days logged.")
        if flowDays > 0 { parts.append("\(flowDays) flow day\(flowDays == 1 ? "" : "s").") }
        if painDays > 0 { parts.append("Pain on \(painDays) day\(painDays == 1 ? "" : "s").") }
        if fatigueDays > 0 { parts.append("Fatigue on \(fatigueDays) day\(fatigueDays == 1 ? "" : "s").") }
        if positiveDays > 0 { parts.append("Positive mood on \(positiveDays) day\(positiveDays == 1 ? "" : "s").") }
        if lowMoodDays > 0 { parts.append("Low mood on \(lowMoodDays) day\(lowMoodDays == 1 ? "" : "s").") }
        return parts.joined(separator: " ")
    }
}

// MARK: - RibbonDimension

enum RibbonDimension: CaseIterable {
    case mood, energy, flow, pain, body, fatigue

    var label: LocalizedStringKey {
        switch self {
        case .mood:    return "Mood"
        case .energy:  return "Energy"
        case .flow:    return "Flow"
        case .pain:    return "Pain"
        case .body:    return "Body"
        case .fatigue: return "Fatigue"
        }
    }

    var color: Color {
        switch self {
        case .mood:    return Color(hex: "7B5EA7")  // violet — bidirectional
        case .energy:  return Color(hex: "2E86C1")  // blue — bidirectional
        case .flow:    return Color(hex: "E87D9E")  // pink
        case .pain:    return Color(hex: "D94F5C")  // red-rose
        case .body:    return Color(hex: "2E9E6B")  // green
        case .fatigue: return Color(hex: "8B9BB4")  // slate
        }
    }

    func value(from score: DimensionScore) -> Double {
        switch self {
        case .mood:    return score.mood
        case .energy:  return score.energy
        case .flow:    return score.flow
        case .pain:    return score.pain
        case .body:    return score.body
        case .fatigue: return score.fatigue
        }
    }
}

// MARK: - RibbonChart

struct RibbonChart: View {
    let scores: [DimensionScore]
    /// Nil means tap targets are disabled (month/3M range)
    let onDayTap: ((Date) -> Void)?

    // Render order: back to front so mood/energy (positive) sit on top
    private let renderOrder: [RibbonDimension] = [
        .fatigue, .body, .pain, .flow, .energy, .mood
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2
            let colW = w / CGFloat(max(scores.count, 1))

            ZStack {
                // Centerline
                Path { p in
                    p.move(to: CGPoint(x: 0, y: midY))
                    p.addLine(to: CGPoint(x: w, y: midY))
                }
                .stroke(Color(.separator).opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Ribbons — back to front
                ForEach(renderOrder, id: \.self) { dim in
                    RibbonPath(
                        scores:    scores,
                        dimension: dim,
                        size:      geo.size
                    )
                }

                // Period start/end markers
                ForEach(Array(scores.enumerated()), id: \.offset) { idx, score in
                    let prevFlow = idx > 0 ? scores[idx - 1].day?.flow : nil
                    let currFlow = score.day?.flow
                    let x = colW * CGFloat(idx) + colW / 2

                    // Period START: previous day had no flow, this day has flow
                    if prevFlow == nil && currFlow != nil {
                        periodMarker(x: x, midY: midY, h: h, isStart: true)
                    }
                    // Period END: this day has flow, next day has no flow (or end of data)
                    else if currFlow != nil {
                        let nextFlow = idx + 1 < scores.count ? scores[idx + 1].day?.flow : nil
                        if nextFlow == nil {
                            periodMarker(x: x, midY: midY, h: h, isStart: false)
                        }
                    }
                }

                // Today highlight
                ForEach(Array(scores.enumerated()), id: \.offset) { idx, score in
                    if Calendar.current.isDateInToday(score.date) {
                        let x = colW * CGFloat(idx) + colW / 2
                        Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(AppTheme.Colors.primaryBlue.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
            }
        }
        .frame(height: 260)
    }

    @ViewBuilder
    private func periodMarker(x: CGFloat, midY: CGFloat, h: CGFloat, isStart: Bool) -> some View {
        let color = RibbonDimension.flow.color
        // Vertical line from top to bottom
        Path { p in
            p.move(to: CGPoint(x: x, y: 4))
            p.addLine(to: CGPoint(x: x, y: h - 4))
        }
        .stroke(color.opacity(isStart ? 0.9 : 0.5),
                style: StrokeStyle(lineWidth: isStart ? 1.5 : 1,
                                   dash: isStart ? [] : [3, 3]))

        // Dot at centerline
        Circle()
            .fill(isStart ? color : color.opacity(0.45))
            .frame(width: isStart ? 7 : 5, height: isStart ? 7 : 5)
            .position(x: x, y: midY)

        // Small label above
        Text(isStart ? "Start" : "End")
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(color.opacity(isStart ? 0.8 : 0.5))
            .position(x: x, y: isStart ? 10 : 10)
    }
}

// MARK: - RibbonPath

struct RibbonPath: View {
    let scores: [DimensionScore]
    let dimension: RibbonDimension
    let size: CGSize

    private let maxAmplitude: CGFloat = 90  // max pixels from centerline

    var body: some View {
        let path = buildPath()
        return ZStack {
            path
                .fill(dimension.color.opacity(0.22))
            path
                .stroke(dimension.color.opacity(0.85), lineWidth: 2)
        }
        .shadow(color: dimension.color.opacity(0.25), radius: 6, x: 0, y: 2)
    }

    private func buildPath() -> Path {
        guard scores.count >= 2 else { return Path() }

        let w      = size.width
        let h      = size.height
        let midY   = h / 2
        let colW   = w / CGFloat(scores.count)

        // X position for each day (center of column)
        func xPos(_ idx: Int) -> CGFloat {
            colW * CGFloat(idx) + colW / 2
        }

        // Y position: value * maxAmplitude offset from midY
        func yPos(_ idx: Int) -> CGFloat {
            let val = dimension.value(from: scores[idx])
            return midY - CGFloat(val) * maxAmplitude
        }

        var path = Path()

        // Build top edge (left to right) using catmull-rom-style cubic beziers
        let points = (0..<scores.count).map { CGPoint(x: xPos($0), y: yPos($0)) }
        path.move(to: points[0])
        for i in 1..<points.count {
            let cp1 = CGPoint(
                x: points[i - 1].x + colW * 0.4,
                y: points[i - 1].y
            )
            let cp2 = CGPoint(
                x: points[i].x - colW * 0.4,
                y: points[i].y
            )
            path.addCurve(to: points[i], control1: cp1, control2: cp2)
        }

        // Close back along centerline
        path.addLine(to: CGPoint(x: xPos(scores.count - 1), y: midY))
        path.addLine(to: CGPoint(x: xPos(0), y: midY))
        path.closeSubpath()

        return path
    }
}

// MARK: - DayDetailCard

struct DayDetailCard: View {
    let date: Date
    let day: CycleDay?
    @ObservedObject var cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showingLogSheet = false

    private let cal = Calendar.current

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let day {
                        // Flow
                        if let flow = day.flow {
                            detailSection(title: "Flow", color: RibbonDimension.flow.color) {
                                flowDots(flow)
                            }
                        }

                        // Pain symptoms
                        let painSymptoms = day.symptoms.filter { $0.category == .pain }
                        if !painSymptoms.isEmpty {
                            detailSection(title: "Pain", color: RibbonDimension.pain.color) {
                                chipGrid(symptoms: Array(painSymptoms), color: RibbonDimension.pain.color)
                            }
                        }

                        // Body symptoms
                        let bodySymptoms = day.symptoms.filter { $0.category == .digestive }
                        if !bodySymptoms.isEmpty {
                            detailSection(title: "Body", color: RibbonDimension.body.color) {
                                chipGrid(symptoms: Array(bodySymptoms), color: RibbonDimension.body.color)
                            }
                        }

                        // Energy symptoms
                        let energySymptoms = day.symptoms.filter { $0.category == .energy }
                        if !energySymptoms.isEmpty {
                            detailSection(title: "Energy", color: RibbonDimension.fatigue.color) {
                                chipGrid(symptoms: Array(energySymptoms), color: RibbonDimension.fatigue.color)
                            }
                        }

                        // Mood
                        if let mood = day.mood {
                            detailSection(title: "Mood", color: RibbonDimension.mood.color) {
                                moodPill(mood)
                            }
                        }

                        // Notes
                        if let notes = day.notes, !notes.isEmpty {
                            detailSection(title: "Note", color: AppTheme.Colors.primaryBlue) {
                                Text(notes)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 44))
                                .foregroundStyle(AppTheme.Colors.primaryBlue.opacity(0.4))
                            Text("Nothing logged")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.mediumGrayText)
                            Text("Tap the pencil to add an entry for this day.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(dateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(AppTheme.Colors.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogDayView(
                    cycleStore: cycleStore,
                    existingDay: day ?? CycleDay(date: date)
                )
            }
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func detailSection<Content: View>(
        title: LocalizedStringKey,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 16)
                Text(title)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Flow dots

    @ViewBuilder
    private func flowDots(_ flow: FlowIntensity) -> some View {
        let levels = FlowIntensity.allCases
        let idx = levels.firstIndex(of: flow) ?? 0
        HStack(spacing: 6) {
            ForEach(Array(levels.enumerated()), id: \.element) { i, level in
                HStack(spacing: 4) {
                    Circle()
                        .fill(i <= idx
                              ? RibbonDimension.flow.color
                              : RibbonDimension.flow.color.opacity(0.15))
                        .frame(width: 10, height: 10)
                    if i <= idx {
                        Text(level.localizedName)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(RibbonDimension.flow.color)
                    }
                }
            }
        }
    }

    // MARK: - Symptom chip grid

    @ViewBuilder
    private func chipGrid(symptoms: [Symptom], color: Color) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(symptoms, id: \.self) { symptom in
                HStack(spacing: 5) {
                    Image(systemName: symptom.sfSymbol)
                        .font(.system(.caption2, design: .default).weight(.medium))
                    Text(symptom.localizedName)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                }
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Mood pill

    @ViewBuilder
    private func moodPill(_ mood: Mood) -> some View {
        let score = moodScore(mood)
        let color: Color = score > 0 ? RibbonDimension.energy.color
                         : score < 0 ? RibbonDimension.pain.color
                         : Color(.secondaryLabel)
        HStack(spacing: 8) {
            Image(systemName: mood.sfSymbol)
                .font(.system(.body, design: .default).weight(.medium))
                .foregroundStyle(color)
            Text(mood.localizedName)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            // Sentiment bar
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i < sentimentLevel(mood)
                              ? color
                              : color.opacity(0.15))
                        .frame(width: 8, height: 14 - CGFloat(abs(i - 2)) * 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func moodScore(_ mood: Mood) -> Double {
        switch mood {
        case .energized, .happy, .confident, .calm, .focused: return 1
        case .neutral:                                          return 0
        default:                                               return -1
        }
    }

    private func sentimentLevel(_ mood: Mood) -> Int {
        switch mood {
        case .energized:  return 5
        case .happy:      return 4
        case .confident:  return 4
        case .calm:       return 3
        case .focused:    return 3
        case .neutral:    return 3
        case .foggy:      return 2
        case .tired:      return 2
        case .sensitive:  return 2
        case .anxious:    return 1
        case .irritable:  return 1
        case .sad:        return 1
        }
    }
}

// MARK: - FlowLayout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                y += rowH + spacing
                x = 0
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowH + spacing
                x = bounds.minX
                rowH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - RibbonSummarySheet

/// Accessible alternative to the ribbon chart — presented via VoiceOver custom action
/// in month and 3-month modes. Shows each logged day as a plain list row.
private struct RibbonSummarySheet: View {
    let scores: [DimensionScore]
    let windowLabel: String
    @Environment(\.dismiss) private var dismiss

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var loggedScores: [DimensionScore] {
        scores.filter { $0.day != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loggedScores.isEmpty {
                    VStack {
                        Spacer()
                        Text("No days logged in this period")
                            .font(AppTheme.Typography.bodyFont)
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                        Spacer()
                    }
                } else {
                    List(loggedScores, id: \.date) { score in
                        Section(header: Text(df.string(from: score.date))) {
                            if score.flow < -0.1 {
                                let label = score.flow <= -0.75 ? String(localized: "Heavy") : score.flow <= -0.5 ? String(localized: "Medium") : score.flow <= -0.25 ? String(localized: "Light") : String(localized: "Spotting")
                                labelRow(String(localized: "Flow"), value: label)
                            }
                            if score.pain < -0.1 {
                                labelRow(String(localized: "Pain"), value: intensityLabel(-score.pain))
                            }
                            if score.fatigue < -0.1 {
                                labelRow(String(localized: "Fatigue"), value: intensityLabel(-score.fatigue))
                            }
                            if score.body < -0.1 {
                                labelRow(String(localized: "Body symptoms"), value: intensityLabel(-score.body))
                            }
                            if abs(score.mood) > 0.1 {
                                labelRow(String(localized: "Mood"), value: score.mood >= 0 ? String(localized: "Positive") : String(localized: "Low"))
                            }
                            if abs(score.energy) > 0.1 {
                                labelRow(String(localized: "Energy"), value: score.energy >= 0 ? String(localized: "High") : String(localized: "Low"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(windowLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func intensityLabel(_ value: Double) -> String {
        value >= 0.7 ? String(localized: "High") : value >= 0.4 ? String(localized: "Moderate") : String(localized: "Mild")
    }

    private func labelRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(AppTheme.Colors.deepGrayText)
            Spacer()
            Text(value).foregroundColor(AppTheme.Colors.mediumGrayText)
        }
        .font(AppTheme.Typography.bodyFont)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    WeekRibbonView(cycleStore: CycleStore(), initialWeek: Date())
}
