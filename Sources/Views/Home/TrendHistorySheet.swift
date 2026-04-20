import SwiftUI

// MARK: - TrendHistorySheet
//
// Month-by-month trend view drilled into from MonthlySummaryView.
// Answers: "How are my symptoms and wellbeing trending over time?"
//
// Structure:
//   - 3/6/9 month picker
//   - 4 vertical bar charts stacked, sharing the same x-axis (month labels):
//       Hot Flashes (days/month), Sleep avg, Energy avg, Stress avg
//   - Tap any month bar → MonthDrillSheet: daily line chart + 7-day MA per metric
//
// Uses calendar-month bucketing (not cycle boundaries) — appropriate for perimenopause
// and menopause where cycles are absent or highly irregular.
// Months with < 5 logged days shown muted as sparse.

// MARK: - Data models

struct MonthBucket: Identifiable {
    let id: Date           // calendar month start
    let shortLabel: String // "Apr"
    let fullLabel: String  // "April 2025"
    let loggedDays: Int
    let hotFlashDays: Int  // days with ≥1 vasomotor symptom
    let sleepAvg: Double?  // 0–4
    let energyAvg: Double? // 0–4
    let stressAvg: Double? // 0–4
    var isSparse: Bool { loggedDays < 5 }
}

// MARK: - TrendHistorySheet

struct TrendHistorySheet: View {
    let cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var monthRange: Int = 3
    @State private var selectedMonth: MonthBucket? = nil

    private var buckets: [MonthBucket] {
        makeBuckets(months: monthRange, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Picker("Range", selection: $monthRange) {
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                        Text("9 months").tag(9)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppTheme.Metrics.cardPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    if buckets.allSatisfy({ $0.loggedDays == 0 }) {
                        emptyState
                    } else {
                        VStack(spacing: 24) {
                            MetricBarChart(
                                title: "Hot flashes",
                                subtitle: "days per month",
                                buckets: buckets,
                                value: { Double($0.hotFlashDays) },
                                maxValue: 30,
                                barColor: AppTheme.Colors.dartPain,
                                selectedMonth: $selectedMonth
                            )
                            Divider()
                            MetricBarChart(
                                title: "Sleep",
                                subtitle: "monthly average",
                                buckets: buckets,
                                value: { $0.sleepAvg },
                                maxValue: 4,
                                barColor: AppTheme.Colors.accentBlue,
                                selectedMonth: $selectedMonth
                            )
                            Divider()
                            MetricBarChart(
                                title: "Energy",
                                subtitle: "monthly average",
                                buckets: buckets,
                                value: { $0.energyAvg },
                                maxValue: 4,
                                barColor: AppTheme.Colors.dartEnergy,
                                selectedMonth: $selectedMonth
                            )
                            Divider()
                            MetricBarChart(
                                title: "Stress",
                                subtitle: "monthly average (lower is better)",
                                buckets: buckets,
                                value: { $0.stressAvg },
                                maxValue: 4,
                                barColor: AppTheme.Colors.secondaryPink,
                                invertScale: true,
                                selectedMonth: $selectedMonth
                            )
                        }
                        .padding(.horizontal, AppTheme.Metrics.cardPadding)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Trend history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedMonth) { month in
                MonthDrillSheet(
                    bucket: month,
                    cycleStore: cycleStore,
                    locale: locale
                )
                .presentationDetents([.large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(.largeTitle))
                .foregroundStyle(AppTheme.Colors.mediumGrayText.opacity(0.35))
            Text("No data logged yet")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
            Text("Log a few days to start seeing your trends.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    // MARK: - Bucket computation

    private func makeBuckets(months: Int, locale: Locale) -> [MonthBucket] {
        let cal = Calendar.current
        let allDays = cycleStore.getAllDays()
        let mostRecentLog = allDays.max(by: { $0.date < $1.date })?.date ?? Date()
        let anchor = cal.startOfDay(for: min(mostRecentLog, Date()))

        guard let anchorMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchor)) else { return [] }

        // Oldest first so charts read left-to-right chronologically
        return (0..<months).compactMap { i -> MonthBucket? in
            guard let monthStart = cal.date(byAdding: .month, value: -(months - 1 - i), to: anchorMonthStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }

            let days = allDays.filter {
                let d = cal.startOfDay(for: $0.date)
                return d >= monthStart && d < monthEnd
            }

            return MonthBucket(
                id:           monthStart,
                shortLabel:   monthStart.formatted(.dateTime.month(.abbreviated).locale(locale)),
                fullLabel:    monthStart.formatted(.dateTime.month(.wide).year().locale(locale)),
                loggedDays:   days.count,
                hotFlashDays: days.filter { $0.symptoms.contains { $0.category == .vasomotor } }.count,
                sleepAvg:     wellbeingAvg(days, keyPath: \.sleepQuality),
                energyAvg:    wellbeingAvg(days, keyPath: \.energyLevel),
                stressAvg:    wellbeingAvg(days, keyPath: \.stressLevel)
            )
        }
    }

    private func wellbeingAvg(_ days: [CycleDay], keyPath: KeyPath<CycleDay, WellbeingLevel?>) -> Double? {
        let values = days.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0) { $0 + $1.rawValue }) / Double(values.count)
    }
}

// MARK: - MetricBarChart

private struct MetricBarChart: View {
    let title: String
    let subtitle: String
    let buckets: [MonthBucket]
    let value: (MonthBucket) -> Double?
    let maxValue: Double
    let barColor: Color
    var invertScale: Bool = false  // for stress: visually flip so lower bar = better
    @Binding var selectedMonth: MonthBucket?

    private let barHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }

            // Bars
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(buckets) { bucket in
                    let val = value(bucket)
                    let filled = val != nil && !bucket.isSparse
                    let rawRatio = val.map { $0 / maxValue } ?? 0
                    let ratio = invertScale ? (1.0 - rawRatio) : rawRatio

                    VStack(spacing: 4) {
                        // Count label above bar
                        if let v = val, !bucket.isSparse {
                            Text(verbatim: labelText(v))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(barColor)
                        } else {
                            Text("—")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.mediumGrayText.opacity(0.4))
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(filled ? barColor : AppTheme.Colors.mediumGrayText.opacity(0.15))
                            .frame(height: max(4, barHeight * ratio))
                            .frame(maxHeight: barHeight, alignment: .bottom)
                            .animation(.easeInOut(duration: 0.3), value: buckets.count)

                        // Month label
                        Text(verbatim: bucket.shortLabel)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.mediumGrayText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if bucket.loggedDays > 0 {
                            selectedMonth = bucket
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(bucket: bucket, val: val))
                    .accessibilityAddTraits(bucket.loggedDays > 0 ? .isButton : [])
                }
            }
            .frame(height: barHeight + 40)  // bars + labels above + labels below
        }
    }

    private func labelText(_ value: Double) -> String {
        // Hot flashes: integer days. Wellbeing: one decimal
        maxValue == 30 ? "\(Int(value.rounded()))" : String(format: "%.1f", value)
    }

    private func accessibilityLabel(bucket: MonthBucket, val: Double?) -> String {
        guard let v = val, !bucket.isSparse else {
            return "\(bucket.fullLabel), \(title): insufficient data"
        }
        return "\(bucket.fullLabel), \(title): \(labelText(v)). Tap to see daily detail."
    }
}

// MARK: - MonthDrillSheet

struct DayPoint: Identifiable {
    let id: Int        // day-of-month index 0-based
    let date: Date
    let hotFlash: Double?   // 1 if had vasomotor symptom, 0 if logged but none, nil if not logged
    let sleep: Double?
    let energy: Double?
    let stress: Double?
}

struct MonthDrillSheet: View {
    let bucket: MonthBucket
    let cycleStore: CycleStore
    let locale: Locale
    @Environment(\.dismiss) private var dismiss

    private var points: [DayPoint] {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: bucket.id) else { return [] }
        let range = cal.dateComponents([.day], from: bucket.id, to: monthEnd).day ?? 30

        return (0..<range).map { i in
            guard let date = cal.date(byAdding: .day, value: i, to: bucket.id) else {
                return DayPoint(id: i, date: bucket.id, hotFlash: nil, sleep: nil, energy: nil, stress: nil)
            }
            let day = cycleStore.getDay(for: date)
            return DayPoint(
                id:       i,
                date:     date,
                hotFlash: day.map { $0.symptoms.contains { $0.category == .vasomotor } ? 1.0 : 0.0 },
                sleep:    day?.sleepQuality.map { Double($0.rawValue) },
                energy:   day?.energyLevel.map { Double($0.rawValue) },
                stress:   day?.stressLevel.map { Double($0.rawValue) }
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    DailyLineChart(
                        title: "Hot flashes",
                        points: points,
                        value: \.hotFlash,
                        maxValue: 1,
                        color: AppTheme.Colors.dartPain,
                        isBinary: true
                    )
                    Divider()
                    DailyLineChart(
                        title: "Sleep",
                        points: points,
                        value: \.sleep,
                        maxValue: 4,
                        color: AppTheme.Colors.accentBlue
                    )
                    Divider()
                    DailyLineChart(
                        title: "Energy",
                        points: points,
                        value: \.energy,
                        maxValue: 4,
                        color: AppTheme.Colors.dartEnergy
                    )
                    Divider()
                    DailyLineChart(
                        title: "Stress",
                        points: points,
                        value: \.stress,
                        maxValue: 4,
                        color: AppTheme.Colors.secondaryPink,
                        invertScale: true
                    )
                }
                .padding(.horizontal, AppTheme.Metrics.cardPadding)
                .padding(.vertical, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(bucket.fullLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - DailyLineChart

private struct DailyLineChart: View {
    let title: String
    let points: [DayPoint]
    let value: KeyPath<DayPoint, Double?>
    let maxValue: Double
    let color: Color
    var invertScale: Bool = false
    var isBinary: Bool = false   // hot flash: 0 or 1, render as dot presence not line

    private let chartHeight: CGFloat = 64
    private let maWindow = 7

    // 7-day moving average over available points
    private var movingAverage: [(Int, Double)] {
        let indexed = points.enumerated().compactMap { (i, p) -> (Int, Double)? in
            guard let v = p[keyPath: value] else { return nil }
            return (i, v)
        }
        guard indexed.count >= 2 else { return [] }

        var result: [(Int, Double)] = []
        for (i, pt) in indexed.enumerated() {
            let window = indexed[max(0, i - maWindow + 1)...i]
            let avg = window.reduce(0.0) { $0 + $1.1 } / Double(window.count)
            result.append((pt.0, avg))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepGrayText)

            GeometryReader { geo in
                let w = geo.size.width
                let h = chartHeight
                let count = points.count
                guard count > 0 else { return AnyView(EmptyView()) }

                let xStep = w / CGFloat(max(count - 1, 1))

                return AnyView(
                    ZStack(alignment: .bottomLeading) {
                        // Raw dots
                        ForEach(points) { pt in
                            if let v = pt[keyPath: value] {
                                let x = CGFloat(pt.id) * xStep
                                let ratio = invertScale ? (1.0 - v / maxValue) : (v / maxValue)
                                let y = h - (h * ratio)
                                Circle()
                                    .fill(color.opacity(0.25))
                                    .frame(width: isBinary ? 8 : 5, height: isBinary ? 8 : 5)
                                    .position(x: x, y: y)
                            }
                        }

                        // 7-day MA line
                        if !isBinary && movingAverage.count >= 2 {
                            Path { path in
                                var started = false
                                for (idx, avg) in movingAverage {
                                    let x = CGFloat(idx) * xStep
                                    let ratio = invertScale ? (1.0 - avg / maxValue) : (avg / maxValue)
                                    let y = h - (h * ratio)
                                    if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                )
            }
            .frame(height: chartHeight)

            // Day-of-month axis labels (1, 8, 15, 22, last)
            GeometryReader { geo in
                let w = geo.size.width
                let count = points.count
                let xStep = w / CGFloat(max(count - 1, 1))
                let labelDays = [0, 7, 14, 21, count - 1].filter { $0 < count }

                ForEach(labelDays, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        .position(x: CGFloat(i) * xStep, y: 6)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let logged = points.compactMap { $0[keyPath: value] }
        guard !logged.isEmpty else { return "\(title): no data logged this month" }
        let avg = logged.reduce(0, +) / Double(logged.count)
        return "\(title) for the month. Average: \(String(format: "%.1f", avg)) out of \(Int(maxValue)). \(logged.count) days logged."
    }
}

// MARK: - MonthlySummaryView tap affordance

extension MonthlySummaryView {
    func withTrendSheet() -> some View {
        TrendSheetWrapper(inner: self)
    }
}

private struct TrendSheetWrapper: View {
    let inner: MonthlySummaryView
    @State private var showingTrend = false

    var body: some View {
        inner
            .contentShape(Rectangle())
            .onTapGesture { showingTrend = true }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText.opacity(0.5))
                    .padding(.top, AppTheme.Metrics.cardPadding)
                    .padding(.trailing, AppTheme.Metrics.cardPadding)
                    .accessibilityHidden(true)
            }
            .sheet(isPresented: $showingTrend) {
                TrendHistorySheet(cycleStore: inner.cycleStore)
                    .presentationDetents([.large])
            }
    }
}

// MARK: - Preview

#if DEBUG || BETA
#Preview("Trend History") {
    TrendHistorySheet(cycleStore: CycleStore())
}
#endif
