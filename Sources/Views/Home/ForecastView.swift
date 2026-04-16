import SwiftUI

// MARK: - ForecastDayDescriptor

/// Pre-computed state for a single cycle-day column in the forecast grid.
/// Built once per forecast row; cells read directly from it — no repeated date math.
struct ForecastDayDescriptor: Identifiable {
    let id: Int                  // 0-based cycle-day index (0 = period center day)
    let isPeriodWindow: Bool
    let isPeriodCenter: Bool
    let isFertileWindow: Bool
    let confidence: Double
}

// MARK: - ForecastView

/// Multi-month at-a-glance forecast grid.
///
/// Layout:
///   Y axis  — calendar months
///   X axis  — 28 cycle-day columns (one per day), tick marks at days 7, 14, 21
///
/// Each month row has three sub-rows:
///   A (period)   — coral fill spanning the uncertainty window
///   B (fertile)  — teal fill spanning the fertile window
///   C (patterns) — reserved for mood/symptom patterns once enough data exists
///
/// Confidence fades via opacity; cycles below 70% confidence also get a dashed border.
struct ForecastView: View {
    @ObservedObject var cycleStore: CycleStore
    @State private var monthCount = 3
    @State private var showingAccessibleForecast = false

    private let cycleDayCount  = 28
    private let monthLabelWidth: CGFloat = 34
    private let horizontalPad: CGFloat   = 16

    // Sub-row heights scale with mode
    private var rowHeight: CGFloat    { monthCount == 3 ? 44 : 30 }
    private var subRowA: CGFloat      { monthCount == 3 ? 16 : 11 }
    private var subRowB: CGFloat      { monthCount == 3 ? 10 :  7 }
    private var subRowC: CGFloat      { monthCount == 3 ? 10 :  7 }
    private var subRowGap: CGFloat    { monthCount == 3 ?  4 :  2 }

    private var forecasts: [CycleForecast] {
        cycleStore.forecastCycles(count: monthCount)
    }

    /// Calendar months that contain at least one forecast event.
    private var displayMonths: [Date] {
        guard let first = forecasts.first, let last = forecasts.last else { return [] }
        let cal = Calendar.current
        var month = cal.date(from: cal.dateComponents([.year, .month], from: first.periodEarliest)) ?? first.periodEarliest
        var months: [Date] = []
        while month <= last.periodLatest {
            months.append(month)
            month = cal.date(byAdding: .month, value: 1, to: month) ?? last.periodLatest
        }
        return months
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if forecasts.isEmpty {
                emptyState
            } else {
                legendRow
                    .padding(.horizontal, horizontalPad)
                    .padding(.bottom, 6)
                    .accessibilityHidden(true)
                ZStack {
                    GeometryReader { geo in
                        let colWidth = columnWidth(totalWidth: geo.size.width)
                        VStack(spacing: 0) {
                            columnHeaderRow(colWidth: colWidth)
                                .padding(.bottom, 4)
                            gridRows(colWidth: colWidth)
                        }
                        .padding(.horizontal, horizontalPad)
                    }
                    .frame(height: gridHeight)
                    .accessibilityHidden(true)

                    // Invisible element that gives VoiceOver a prose summary of the grid
                    Text(accessibilitySummary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(0)
                        .accessibilityLabel(accessibilitySummary)
                        .accessibilityAction(named: "Show forecast as list") {
                            showingAccessibleForecast = true
                        }
                }
                .frame(height: gridHeight)
                .padding(.bottom, 14)
            }
            if !forecasts.isEmpty {
                forecastDisclaimer
                    .padding(.horizontal, horizontalPad)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityIdentifier("home.forecastView")
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showingAccessibleForecast) {
            ForecastListSheet(forecasts: forecasts)
        }
    }

    // MARK: - Accessibility summary

    /// Builds a prose description of upcoming forecasts for VoiceOver users
    /// who cannot read the visual grid.
    private var accessibilitySummary: String {
        guard !forecasts.isEmpty else {
            return "Cycle Forecast. Log your first period to see a forecast."
        }
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        var parts: [String] = ["Cycle Forecast."]
        for (i, f) in forecasts.prefix(3).enumerated() {
            let ordinal = i == 0 ? "Next period" : i == 1 ? "Following period" : "Period after that"
            let earliest = df.string(from: f.periodEarliest)
            let latest   = df.string(from: f.periodLatest)
            let pct      = Int(f.confidence * 100)
            var entry = "\(ordinal) expected \(earliest) to \(latest), \(pct)% confidence."
            if let fs = f.fertileWindowStart, let fe = f.fertileWindowEnd, i == 0 {
                entry += " Fertile window \(df.string(from: fs)) to \(df.string(from: fe))."
            }
            parts.append(entry)
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Cycle Forecast")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            Spacer()
            Picker("Forecast range", selection: $monthCount) {
                Text("3 mo").tag(3)
                    .accessibilityLabel(String(localized: "3 months"))
                Text("6 mo").tag(6)
                    .accessibilityLabel(String(localized: "6 months"))
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
            .accessibilityHint(String(localized: "Select how many months to forecast"))
        }
        .padding(.horizontal, horizontalPad)
        .padding(.vertical, 12)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendChip(color: AppTheme.Colors.forecastPeriod,  label: "Period")
            legendChip(color: AppTheme.Colors.forecastFertile, label: "Fertile")
            Spacer()
            Text("Faded = less certain")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
    }

    private func legendChip(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Column Headers

    private func columnHeaderRow(colWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Month label spacer
            Color.clear.frame(width: monthLabelWidth)

            // Day tick labels at 7, 14, 21 — positioned via offset
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

    // MARK: - Grid

    private func gridRows(colWidth: CGFloat) -> some View {
        VStack(spacing: 6) {
            ForEach(displayMonths, id: \.self) { month in
                monthRow(month: month, colWidth: colWidth)
            }
        }
    }

    private func monthRow(month: Date, colWidth: CGFloat) -> some View {
        let matchingForecasts = forecastsFor(month: month)
        let descriptors = mergedDescriptors(for: matchingForecasts, month: month)
        let confidence = matchingForecasts.map(\.confidence).min() ?? 1.0

        return HStack(spacing: 0) {
            // Month label
            Text(shortMonth(month))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(AppTheme.Colors.deepGrayText)
                .frame(width: monthLabelWidth, alignment: .leading)

            // Day strip
            dayStrip(descriptors: descriptors, colWidth: colWidth, confidence: confidence)

        }
        .frame(height: rowHeight)
    }

    // MARK: - Day Strip

    private func dayStrip(descriptors: [ForecastDayDescriptor], colWidth: CGFloat, confidence: Double) -> some View {
        let useDash = confidence < 0.7

        return ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.background.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Week-boundary tick marks at days 7, 14, 21
            ForEach([7, 14, 21], id: \.self) { day in
                Rectangle()
                    .fill(AppTheme.Colors.mediumGrayText.opacity(0.2))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: colWidth * CGFloat(day))
            }

            VStack(spacing: subRowGap) {
                // Sub-row A: period window
                periodSubRow(descriptors: descriptors, colWidth: colWidth, confidence: confidence, useDash: useDash)
                    .frame(height: subRowA)

                // Sub-row B: fertile window
                fertileSubRow(descriptors: descriptors, colWidth: colWidth, confidence: confidence)
                    .frame(height: subRowB)

                // Sub-row C: reserved (mood / symptom patterns — empty until data layer is built)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.clear)
                    .frame(height: subRowC)
            }
            .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Groups a sorted list of column indices into contiguous runs.
    /// e.g. [0,1,2,5,6] → [(0,2), (5,6)]
    private func consecutiveRuns(from ids: [Int]) -> [(first: Int, last: Int)] {
        guard !ids.isEmpty else { return [] }
        var runs: [(first: Int, last: Int)] = []
        var runStart = ids[0]
        var runEnd   = ids[0]
        for id in ids.dropFirst() {
            if id == runEnd + 1 {
                runEnd = id
            } else {
                runs.append((runStart, runEnd))
                runStart = id
                runEnd   = id
            }
        }
        runs.append((runStart, runEnd))
        return runs
    }

    private func periodSubRow(
        descriptors: [ForecastDayDescriptor],
        colWidth: CGFloat,
        confidence: Double,
        useDash: Bool
    ) -> some View {
        guard !descriptors.isEmpty else {
            return AnyView(Color.clear)
        }
        let periodIds = descriptors.filter(\.isPeriodWindow).map(\.id)
        guard !periodIds.isEmpty else { return AnyView(Color.clear) }
        let runs = consecutiveRuns(from: periodIds)
        let centerIdx = descriptors.first(where: \.isPeriodCenter)?.id

        return AnyView(
            ZStack(alignment: .leading) {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                    let x     = colWidth * CGFloat(run.first)
                    let width = colWidth * CGFloat(run.last - run.first + 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.Colors.forecastPeriod.opacity(confidence))
                            .frame(width: max(colWidth, width))
                        if useDash {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    AppTheme.Colors.forecastPeriod.opacity(confidence * 0.8),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )
                                .frame(width: max(colWidth, width))
                        }
                    }
                    .offset(x: x)
                }
                // Center dot — most likely day
                if let ci = centerIdx {
                    Circle()
                        .fill(Color.white.opacity(confidence * 0.9))
                        .frame(width: 5, height: 5)
                        .offset(x: colWidth * CGFloat(ci) + colWidth / 2 - 2.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        )
    }

    private func fertileSubRow(
        descriptors: [ForecastDayDescriptor],
        colWidth: CGFloat,
        confidence: Double
    ) -> some View {
        guard !descriptors.isEmpty else { return AnyView(Color.clear) }
        let fertileIds = descriptors.filter(\.isFertileWindow).map(\.id)
        guard !fertileIds.isEmpty else { return AnyView(Color.clear) }
        let runs = consecutiveRuns(from: fertileIds)

        return AnyView(
            ZStack(alignment: .leading) {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                    let x     = colWidth * CGFloat(run.first)
                    let width = colWidth * CGFloat(run.last - run.first + 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.Colors.forecastFertile.opacity(confidence * 0.85))
                        .frame(width: max(colWidth, width))
                        .offset(x: x)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        )
    }

    // MARK: - Descriptor Builder

    /// Builds 28 descriptors anchored so that `periodCenter` lands at the
    /// column that represents its day-within-month position.
    private func buildDescriptors(for forecast: CycleForecast, month: Date) -> [ForecastDayDescriptor] {
        let cal = Calendar.current
        // Anchor: first day of this month
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month

        return (0..<cycleDayCount).map { col in
            guard let colDate = cal.date(byAdding: .day, value: col, to: monthStart) else {
                return ForecastDayDescriptor(id: col, isPeriodWindow: false, isPeriodCenter: false, isFertileWindow: false, confidence: forecast.confidence)
            }
            let isPeriod  = colDate >= forecast.periodEarliest && colDate <= forecast.periodLatest
            let isCenter  = cal.isDate(colDate, inSameDayAs: forecast.periodCenter)
            let isFertile: Bool = {
                guard let fs = forecast.fertileWindowStart, let fe = forecast.fertileWindowEnd else { return false }
                return colDate >= fs && colDate <= fe
            }()
            return ForecastDayDescriptor(
                id: col,
                isPeriodWindow: isPeriod,
                isPeriodCenter: isCenter,
                isFertileWindow: isFertile,
                confidence: forecast.confidence
            )
        }
    }

    // MARK: - Helpers

    private func forecastsFor(month: Date) -> [CycleForecast] {
        let cal = Calendar.current
        let monthComponents = cal.dateComponents([.year, .month], from: month)
        guard let monthStart = cal.date(from: monthComponents),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }
        return forecasts.filter { forecast in
            forecast.periodEarliest <= monthEnd && forecast.periodLatest >= monthStart
        }
    }

    /// Merges descriptors from multiple forecasts overlapping the same calendar month.
    /// Per-column: OR the booleans, take the minimum confidence.
    private func mergedDescriptors(for forecasts: [CycleForecast], month: Date) -> [ForecastDayDescriptor] {
        guard !forecasts.isEmpty else { return [] }
        let allDescriptors = forecasts.map { buildDescriptors(for: $0, month: month) }
        return (0..<cycleDayCount).map { col in
            let col_sets = allDescriptors.map { $0[col] }
            return ForecastDayDescriptor(
                id: col,
                isPeriodWindow:  col_sets.contains(where: \.isPeriodWindow),
                isPeriodCenter:  col_sets.contains(where: \.isPeriodCenter),
                isFertileWindow: col_sets.contains(where: \.isFertileWindow),
                confidence: col_sets.map(\.confidence).min() ?? 1.0
            )
        }
    }

    private func columnWidth(totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth - monthLabelWidth - (horizontalPad * 2)
        return available / CGFloat(cycleDayCount)
    }

    private var gridHeight: CGFloat {
        let rows = CGFloat(displayMonths.count)
        let headerH: CGFloat = 18
        return rows * (rowHeight + 6) + headerH
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("Log your first period to see a forecast")
            .font(AppTheme.Typography.captionFont)
            .foregroundColor(AppTheme.Colors.mediumGrayText)
            .padding()
    }

    // MARK: - Disclaimer

    private var forecastDisclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The fertile window shown is an estimate for cycle awareness only. Clio Daye is not a contraceptive method and cannot predict fertility with certainty.")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Predictions assume a typical 14-day luteal phase. Your experience may vary.")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(AppTheme.Colors.background.opacity(0.6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ForecastListSheet

/// Accessible alternative to the forecast grid — shown via VoiceOver custom action.
/// Presents each forecast cycle as a plain list row with all dates spelled out.
private struct ForecastListSheet: View {
    let forecasts: [CycleForecast]
    @Environment(\.dismiss) private var dismiss

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(forecasts.enumerated()), id: \.offset) { i, f in
                    Section(header: Text(i == 0 ? "Next cycle" : "Cycle \(i + 1)")) {
                        row(label: "Period window",
                            value: "\(df.string(from: f.periodEarliest)) – \(df.string(from: f.periodLatest))")
                        row(label: "Most likely start", value: df.string(from: f.periodCenter))
                        if let fs = f.fertileWindowStart, let fe = f.fertileWindowEnd {
                            row(label: "Fertile window",
                                value: "\(df.string(from: fs)) – \(df.string(from: fe))")
                        }
                        row(label: "Confidence", value: "\(Int(f.confidence * 100))%")
                    }
                }
            }
            .navigationTitle("Cycle Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            Spacer()
            Text(value)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
        .font(AppTheme.Typography.bodyFont)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        ForecastView(cycleStore: CycleStore())
            .padding()
    }
    .background(AppTheme.Colors.background)
}
