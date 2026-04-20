import SwiftUI

// MARK: - TrendHistorySheet
//
// Month-by-month trend view drilled into from MonthlySummaryView.
// Answers: "How are my symptoms trending over time?"
//
// Structure:
//   - 3/6/9 month picker
//   - 4 vertical bar charts: Hot Flashes (days/month), Energy, Sleep, Mood
//   - Tap any month bar → MonthDrillSheet: weekly grouped line charts
//
// Uses calendar-month bucketing (not cycle boundaries) — appropriate for perimenopause
// and menopause where cycles are absent or highly irregular.
// Months with < 5 logged days shown muted as sparse.
//
// Derived scores (no separate capture — computed from existing symptom/mood data):
//   Energy:  highEnergy → +1, fatigue/brainFog → -1, else 0
//   Sleep:   insomnia → -1, else 0
//   Mood:    positive moods → +1, neutral → 0, negative moods → -1
// Monthly averages are shown on a -1…+1 scale.

// MARK: - Data models

struct MonthBucket: Identifiable {
    let id: Date           // calendar month start
    let shortLabel: String // "Apr"
    let fullLabel: String  // "April 2025"
    let loggedDays: Int
    let hotFlashDays: Int  // days with ≥1 vasomotor symptom
    let avgEnergy: Double? // nil if sparse, else average of per-day energy scores (-1…+1)
    let avgSleep: Double?  // nil if sparse, else average of per-day sleep scores (-1…0)
    let avgMood: Double?   // nil if sparse, else average of per-day mood scores (-1…+1)
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
                        VStack(spacing: 28) {
                            MetricBarChart(
                                title: "Hot flashes",
                                subtitle: "days per month",
                                buckets: buckets,
                                value: { Double($0.hotFlashDays) },
                                maxValue: 30,
                                barColor: AppTheme.Colors.dartPain,
                                selectedMonth: $selectedMonth
                            )
                            MetricBarChart(
                                title: "Energy",
                                subtitle: "avg score per month",
                                buckets: buckets,
                                value: { $0.avgEnergy },
                                maxValue: 1,
                                barColor: AppTheme.Colors.dartEnergy,
                                selectedMonth: $selectedMonth
                            )
                            MetricBarChart(
                                title: "Sleep",
                                subtitle: "avg score per month",
                                buckets: buckets,
                                value: { $0.avgSleep.map { $0 + 1 } },  // shift -1…0 → 0…1 for bar height
                                maxValue: 1,
                                barColor: AppTheme.Colors.primaryBlue,
                                invertedLabel: true,  // lower raw score = worse sleep
                                selectedMonth: $selectedMonth
                            )
                            MetricBarChart(
                                title: "Mood",
                                subtitle: "avg score per month",
                                buckets: buckets,
                                value: { $0.avgMood.map { ($0 + 1) / 2 } },  // shift -1…+1 → 0…1
                                maxValue: 1,
                                barColor: AppTheme.Colors.dartMood,
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

            let energyScores = days.map { energyScore(for: $0) }
            let sleepScores  = days.map { sleepScore(for: $0) }
            let moodScores   = days.compactMap { moodScore(for: $0) }

            let sparse = days.count < 5

            return MonthBucket(
                id:           monthStart,
                shortLabel:   monthStart.formatted(.dateTime.month(.abbreviated).locale(locale)),
                fullLabel:    monthStart.formatted(.dateTime.month(.wide).year().locale(locale)),
                loggedDays:   days.count,
                hotFlashDays: days.filter { $0.symptoms.contains { $0.category == .vasomotor } }.count,
                avgEnergy:    sparse || energyScores.isEmpty ? nil : energyScores.reduce(0, +) / Double(energyScores.count),
                avgSleep:     sparse || sleepScores.isEmpty  ? nil : sleepScores.reduce(0, +)  / Double(sleepScores.count),
                avgMood:      sparse || moodScores.isEmpty   ? nil : moodScores.reduce(0, +)   / Double(moodScores.count)
            )
        }
    }

    // MARK: - Derived score helpers

    /// Energy score for a single day: highEnergy → +1, fatigue/brainFog → -1, else 0
    private func energyScore(for day: CycleDay) -> Double {
        if day.symptoms.contains(.highEnergy) { return 1 }
        if day.symptoms.contains(.fatigue) || day.symptoms.contains(.brainFog) { return -1 }
        return 0
    }

    /// Sleep score for a single day: insomnia → -1, else 0
    private func sleepScore(for day: CycleDay) -> Double {
        day.symptoms.contains(.insomnia) ? -1 : 0
    }

    /// Mood score for a single day — nil if no mood logged
    private func moodScore(for day: CycleDay) -> Double? {
        switch day.mood {
        case .energized, .happy, .confident, .calm, .focused: return 1
        case .neutral: return 0
        case .foggy, .tired, .sensitive, .anxious, .irritable, .sad: return -1
        case nil: return nil
        }
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
    var invertedLabel: Bool = false  // when value is shifted for display but label should show original
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
                    let ratio = val.map { $0 / maxValue } ?? 0

                    VStack(spacing: 4) {
                        // Score label above bar
                        if let v = val, !bucket.isSparse {
                            Text(verbatim: scoreLabel(v, bucket: bucket))
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

    /// Display label for the score value above the bar.
    /// Hot flashes (maxValue==30): integer day count.
    /// Shifted -1…+1 scores (maxValue==1): show original unshifted value as "+0.4" etc.
    private func scoreLabel(_ displayValue: Double, bucket: MonthBucket) -> String {
        if maxValue == 30 {
            return "\(Int(displayValue.rounded()))"
        }
        // Recover original -1…+1 value from shifted display value
        let original: Double
        if invertedLabel {
            // sleep: shifted by +1, recover by -1
            original = displayValue - 1
        } else if title == "Mood" {
            // mood: shifted by (v+1)/2, recover by v*2-1
            original = displayValue * 2 - 1
        } else {
            original = displayValue
        }
        let s = String(format: "%.1f", original)
        return original > 0 ? "+\(s)" : s
    }

    private func accessibilityLabel(bucket: MonthBucket, val: Double?) -> String {
        guard let v = val, !bucket.isSparse else {
            return "\(bucket.fullLabel), \(title): insufficient data"
        }
        return "\(bucket.fullLabel), \(title): \(scoreLabel(v, bucket: bucket)). Tap to see weekly detail."
    }
}

// MARK: - MonthDrillSheet

struct WeekPoint: Identifiable {
    let id: Int          // week index 0-based
    let label: String    // "Wk 1"
    let hotFlash: Double?  // fraction of logged days with hot flash (0…1), nil if no logged days
    let energy: Double?    // avg energy score (-1…+1), nil if no logged days
    let sleep: Double?     // avg sleep score (-1…0), nil if no logged days
    let mood: Double?      // avg mood score (-1…+1), nil if no mood logged
}

struct MonthDrillSheet: View {
    let bucket: MonthBucket
    let cycleStore: CycleStore
    let locale: Locale
    @Environment(\.dismiss) private var dismiss

    private var weeks: [WeekPoint] {
        let cal = Calendar.current
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: bucket.id) else { return [] }
        let daysInMonth = cal.dateComponents([.day], from: bucket.id, to: monthEnd).day ?? 30

        // Bucket days into 4 weeks: wk0=days 0-6, wk1=7-13, wk2=14-20, wk3=21-end
        return (0..<4).compactMap { wk -> WeekPoint? in
            let startOffset = wk * 7
            guard startOffset < daysInMonth else { return nil }
            let endOffset = min(startOffset + 7, daysInMonth)

            let days: [CycleDay] = (startOffset..<endOffset).compactMap { offset in
                guard let date = cal.date(byAdding: .day, value: offset, to: bucket.id) else { return nil }
                return cycleStore.getDay(for: date)
            }
            let loggedCount = days.count

            let hotFlashFrac: Double? = loggedCount == 0 ? nil :
                Double(days.filter { $0.symptoms.contains { $0.category == .vasomotor } }.count) / Double(loggedCount)

            let energyScores = days.map { energyScore(for: $0) }
            let avgEnergy: Double? = loggedCount == 0 ? nil :
                energyScores.reduce(0, +) / Double(loggedCount)

            let sleepScores = days.map { sleepScore(for: $0) }
            let avgSleep: Double? = loggedCount == 0 ? nil :
                sleepScores.reduce(0, +) / Double(loggedCount)

            let moodScores = days.compactMap { moodScore(for: $0) }
            let avgMood: Double? = moodScores.isEmpty ? nil :
                moodScores.reduce(0, +) / Double(moodScores.count)

            return WeekPoint(
                id:       wk,
                label:    "Wk \(wk + 1)",
                hotFlash: hotFlashFrac,
                energy:   avgEnergy,
                sleep:    avgSleep,
                mood:     avgMood
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    WeeklyLineChart(
                        title: "Hot flashes",
                        weeks: weeks,
                        value: \.hotFlash,
                        minValue: 0, maxValue: 1,
                        color: AppTheme.Colors.dartPain
                    )
                    WeeklyLineChart(
                        title: "Energy",
                        weeks: weeks,
                        value: \.energy,
                        minValue: -1, maxValue: 1,
                        color: AppTheme.Colors.dartEnergy
                    )
                    WeeklyLineChart(
                        title: "Sleep",
                        weeks: weeks,
                        value: \.sleep,
                        minValue: -1, maxValue: 0,
                        color: AppTheme.Colors.primaryBlue
                    )
                    WeeklyLineChart(
                        title: "Mood",
                        weeks: weeks,
                        value: \.mood,
                        minValue: -1, maxValue: 1,
                        color: AppTheme.Colors.dartMood
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

    // MARK: - Derived score helpers (duplicated from TrendHistorySheet for struct isolation)

    private func energyScore(for day: CycleDay) -> Double {
        if day.symptoms.contains(.highEnergy) { return 1 }
        if day.symptoms.contains(.fatigue) || day.symptoms.contains(.brainFog) { return -1 }
        return 0
    }

    private func sleepScore(for day: CycleDay) -> Double {
        day.symptoms.contains(.insomnia) ? -1 : 0
    }

    private func moodScore(for day: CycleDay) -> Double? {
        switch day.mood {
        case .energized, .happy, .confident, .calm, .focused: return 1
        case .neutral: return 0
        case .foggy, .tired, .sensitive, .anxious, .irritable, .sad: return -1
        case nil: return nil
        }
    }
}

// MARK: - WeeklyLineChart

private struct WeeklyLineChart: View {
    let title: String
    let weeks: [WeekPoint]
    let value: KeyPath<WeekPoint, Double?>
    let minValue: Double   // e.g. -1 for score charts, 0 for hot flash
    let maxValue: Double
    let color: Color

    private let chartHeight: CGFloat = 64

    /// Normalise a raw value to 0…1 for y-position
    private func norm(_ v: Double) -> Double {
        guard maxValue > minValue else { return 0 }
        return (v - minValue) / (maxValue - minValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepGrayText)

            GeometryReader { geo in
                let w = geo.size.width
                let h = chartHeight
                let count = weeks.count
                guard count > 0 else { return AnyView(EmptyView()) }
                let xStep = w / CGFloat(max(count - 1, 1))

                let available = weeks.compactMap { pt -> (Int, Double)? in
                    guard let v = pt[keyPath: value] else { return nil }
                    return (pt.id, v)
                }

                return AnyView(
                    ZStack(alignment: .bottomLeading) {
                        // Zero/midline for score charts
                        if minValue < 0 {
                            let zeroY = h - (h * norm(0))
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: zeroY))
                                path.addLine(to: CGPoint(x: w, y: zeroY))
                            }
                            .stroke(AppTheme.Colors.mediumGrayText.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Dots for all available weeks
                        ForEach(weeks) { pt in
                            if let v = pt[keyPath: value] {
                                let x = CGFloat(pt.id) * xStep
                                let y = h - (h * norm(v))
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                        }

                        // Connecting line through available weeks
                        if available.count >= 2 {
                            Path { path in
                                var started = false
                                for (idx, v) in available {
                                    let x = CGFloat(idx) * xStep
                                    let y = h - (h * norm(v))
                                    if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(color.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                )
            }
            .frame(height: chartHeight)

            // Week axis labels
            GeometryReader { geo in
                let w = geo.size.width
                let count = weeks.count
                let xStep = w / CGFloat(max(count - 1, 1))

                ForEach(weeks) { pt in
                    Text(verbatim: pt.label)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        .position(x: CGFloat(pt.id) * xStep, y: 6)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let values = weeks.compactMap { $0[keyPath: value] }
        guard !values.isEmpty else { return "\(title): no data logged this month" }
        let avg = values.reduce(0, +) / Double(values.count)
        return "\(title) for the month. Weekly average: \(String(format: "%.1f", avg)). \(values.count) weeks with data."
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
