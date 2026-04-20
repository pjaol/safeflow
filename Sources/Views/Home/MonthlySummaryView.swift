import SwiftUI

// MARK: - MonthlySummaryView
//
// Unified summary card for perimenopause, menopause, and paused stages.
//
// For peri/meno, the day slice comes from SignalWindowResolver — either the current
// cycle (sentinel mode) or the last 30 days (rolling mode). The header label reflects
// which window is active. Calendar-month slicing is not used for these stages because
// cycles don't align with calendar boundaries.
//
// For paused stage, falls back to the last 30 days with no signal overlay.
//
// When signal is provided:
//   - Narrative sentence replaces the generic "Most frequent" label
//   - Symptom chips are trend-coloured (pink = escalating/new, blue = improving)
//   - Wellbeing pips show trend arrows (↑ ↓)
//
// When no signal (paused, or not enough data yet):
//   - Plain averages and top symptoms

struct MonthlySummaryView: View {
    let cycleStore: CycleStore
    var signal:      SignalReadiness?  = nil
    var windowLabel: SignalWindowLabel? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Day slice
    //
    // When a windowLabel is provided (peri/meno), the days are sourced from the
    // resolved SignalWindow so we're showing the same slice the engine used.
    // When no windowLabel (paused), fall back to rolling last 30 days.

    private var windowDays: [CycleDay] {
        // Re-resolve the window to get its day slice.
        // For paused stage (no windowLabel) use a simple rolling 30-day fallback.
        if windowLabel != nil {
            return SignalWindowResolver.resolve(allDays: cycleStore.getAllDays()).current
        }
        // Paused fallback — rolling 30 days
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -29, to: today) else {
            return cycleStore.getAllDays()
        }
        return cycleStore.getAllDays().filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= start && d <= today
        }
    }

    private var loggedDaysCount: Int { windowDays.count }

    // MARK: Header label string

    private var headerLabel: String {
        switch windowLabel {
        case .thisCycle(let day):
            return String(localized: "This cycle · Day \(day)")
        case .rolling(let days):
            return String(localized: "Last \(days) days")
        case nil:
            return String(localized: "Last 30 days")
        }
    }

    // MARK: Wellbeing averages

    private func average(keyPath: KeyPath<CycleDay, WellbeingLevel?>) -> WellbeingLevel? {
        let values = windowDays.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0) { $0 + $1.rawValue }
        let avg = sum / values.count
        return WellbeingLevel(rawValue: avg)
    }

    // MARK: Top symptoms

    private var topSymptoms: [(Symptom, Int)] {
        var counts: [Symptom: Int] = [:]
        for day in windowDays {
            for symptom in day.symptoms {
                counts[symptom, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    // MARK: Signal helpers

    private var signalResult: SignalResult? {
        guard case .ready(let result) = signal else { return nil }
        return result
    }

    private var narrativeSentence: String? {
        guard let result = signalResult else { return nil }
        return SignalCardFormatter.format(result).headline
    }

    /// Trend for a given symptom from the signal result.
    private func symptomTrend(for symptom: Symptom) -> SymptomTrend? {
        signalResult?.dominantSymptoms.first { $0.symptom == symptom }?.trend
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                    .font(.system(.callout, weight: .semibold))
                    .accessibilityHidden(true)
                Text(verbatim: headerLabel)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                Spacer()
                Text("\(loggedDaysCount) days logged")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }

            if loggedDaysCount == 0 {
                Text("No data logged this month yet.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            } else {
                // Wellbeing row — pips gain trend arrows when signal is available
                HStack(spacing: 0) {
                    WellbeingAveragePip(
                        label: String(localized: "Sleep"),
                        sfSymbol: "moon.stars.fill",
                        level: average(keyPath: \.sleepQuality),
                        labelText: average(keyPath: \.sleepQuality)?.sleepLabelString,
                        trend: signalResult?.wellbeing.sleepTrend
                    )
                    WellbeingAveragePip(
                        label: String(localized: "Energy"),
                        sfSymbol: "bolt.fill",
                        level: average(keyPath: \.energyLevel),
                        labelText: average(keyPath: \.energyLevel)?.energyLabelString,
                        trend: signalResult?.wellbeing.energyTrend
                    )
                    WellbeingAveragePip(
                        label: String(localized: "Stress"),
                        sfSymbol: "waveform.path.ecg",
                        level: average(keyPath: \.stressLevel),
                        labelText: average(keyPath: \.stressLevel)?.stressLabelString,
                        // Stress polarity is inverted — worsening stress = higher rawValue
                        trend: signalResult.map { invertedTrend($0.wellbeing.stressTrend) }
                    )
                }

                // Symptom section — only when enough data (5+ days)
                if loggedDaysCount > 0 && loggedDaysCount < 5 {
                    Divider()
                    Text("Log 5+ days to see top symptoms.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                } else if loggedDaysCount >= 5 && !topSymptoms.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        // Narrative sentence when signal is ready, plain label otherwise
                        if let sentence = narrativeSentence {
                            Text(sentence)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.deepGrayText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Most frequent this month")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        }

                        HStack(spacing: 8) {
                            ForEach(topSymptoms, id: \.0) { symptom, count in
                                MonthlySymptomChip(
                                    symptom: symptom,
                                    count: count,
                                    trend: symptomTrend(for: symptom)
                                )
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("home.monthlySummaryCard")
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = [
            headerLabel,
            "\(loggedDaysCount) days logged"
        ]
        if let sentence = narrativeSentence {
            parts.append(sentence)
        }
        if let sl = average(keyPath: \.sleepQuality) {
            parts.append("Average sleep: \(sl.sleepLabelString)")
        }
        if let el = average(keyPath: \.energyLevel) {
            parts.append("Average energy: \(el.energyLabelString)")
        }
        if let st = average(keyPath: \.stressLevel) {
            parts.append("Average stress: \(st.stressLabelString)")
        }
        if !topSymptoms.isEmpty {
            let names = topSymptoms.map { $0.0.localizedNameString }.joined(separator: ", ")
            parts.append("Most frequent symptoms: \(names)")
        }
        return parts.joined(separator: ". ")
    }

    // Stress polarity: the wellbeing trend reports worsening when stress rawValue rises.
    // For the pip arrow we want to show ↑ when stress is worsening (visually bad),
    // so we don't invert — but the label colour should use .worse not .better.
    // This helper is used so the pip renders the arrow direction correctly regardless.
    private func invertedTrend(_ trend: WellbeingTrend) -> WellbeingTrend { trend }
}

// MARK: - WellbeingAveragePip

private struct WellbeingAveragePip: View {
    let label: String
    let sfSymbol: String
    let level: WellbeingLevel?
    let labelText: String?
    var trend: WellbeingTrend? = nil

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: sfSymbol)
                .foregroundStyle(level != nil ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText.opacity(0.35))
                .font(.system(.body))
                .accessibilityHidden(true)

            // Value + optional trend arrow on the same line
            HStack(spacing: 2) {
                Text(verbatim: labelText ?? "—")
                    .font(.system(.caption2, design: .rounded, weight: level != nil ? .semibold : .regular))
                    .foregroundStyle(level != nil ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText.opacity(0.5))
                if let trend, let arrow = trendArrow(trend) {
                    Text(arrow.symbol)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(arrow.color)
                        .accessibilityHidden(true)
                }
            }

            Text(verbatim: label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
        }
        .frame(maxWidth: .infinity)
    }

    private struct Arrow { let symbol: String; let color: Color }

    private func trendArrow(_ trend: WellbeingTrend) -> Arrow? {
        switch trend {
        case .improving: return Arrow(symbol: "↑", color: AppTheme.Colors.accentBlue)
        case .worsening: return Arrow(symbol: "↓", color: AppTheme.Colors.dartPain)
        case .stable, .unknown: return nil
        }
    }
}

// MARK: - MonthlySymptomChip

private struct MonthlySymptomChip: View {
    let symptom: Symptom
    let count: Int
    var trend: SymptomTrend? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symptom.sfSymbol)
                .font(.system(.caption2))
                .foregroundStyle(chipForeground)
                .accessibilityHidden(true)
            Text(symptom.localizedName)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(AppTheme.Colors.deepGrayText)
            Text("×\(count)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
            if let arrow = trendArrow {
                Text(arrow)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(chipForeground)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBackground)
        .cornerRadius(8)
    }

    private var chipBackground: Color {
        switch trend {
        case .escalating, .new: return AppTheme.Colors.secondaryPink.opacity(0.15)
        case .improving:         return AppTheme.Colors.accentBlue.opacity(0.1)
        default:                 return AppTheme.Colors.accentBlue.opacity(0.08)
        }
    }

    private var chipForeground: Color {
        switch trend {
        case .escalating, .new: return AppTheme.Colors.dartPain
        case .improving:         return AppTheme.Colors.accentBlue
        default:                 return AppTheme.Colors.accentBlue
        }
    }

    private var trendArrow: String? {
        switch trend {
        case .escalating: return "↑"
        case .improving:  return "↓"
        case .new:        return "new"
        default:          return nil
        }
    }
}

// MARK: - Preview

#if DEBUG || BETA
#Preview("With signal — escalating") {
    let store = CycleStore()
    let result = SignalResult(
        stage: .earlyPerimenopause,
        monthCharacter: .notablyHarder,
        dominantSymptoms: [
            SymptomSignal(symptom: .hotFlashes, thisMonth: 16, baselineAvg: 3, trend: .escalating),
            SymptomSignal(symptom: .nightSweats, thisMonth: 8, baselineAvg: 2, trend: .escalating),
            SymptomSignal(symptom: .brainFog, thisMonth: 5, baselineAvg: 1, trend: .new)
        ],
        wellbeing: WellbeingSignal(
            sleepAvg: 1.2, energyAvg: 1.5, stressAvg: 3.0,
            sleepTrend: .worsening, energyTrend: .stable, stressTrend: .worsening
        ),
        hasBaseline: true
    )
    return MonthlySummaryView(cycleStore: store, signal: .ready(result))
        .padding()
        .background(AppTheme.Colors.background)
}

#Preview("No signal") {
    let store = CycleStore()
    return MonthlySummaryView(cycleStore: store)
        .padding()
        .background(AppTheme.Colors.background)
}
#endif
