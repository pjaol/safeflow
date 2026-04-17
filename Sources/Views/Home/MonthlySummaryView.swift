import SwiftUI

// MARK: - MonthlySummaryView
//
// A compact monthly summary card showing:
// - Wellbeing averages (sleep/energy/stress) for the logged days this month
// - Top 3 symptoms by frequency
// - Data-density scaling: shows more content when more days are logged
//
// Shown for perimenopause, menopause, and paused stages (where cycle predictions
// are secondary or absent). Regular/irregular users still see the ForecastView instead.

struct MonthlySummaryView: View {
    let cycleStore: CycleStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(LifeStage.defaultsKey) private var lifeStage: LifeStage = .regular

    private var currentMonth: Date { Calendar.current.startOfDay(for: Date()) }

    private var daysThisMonth: [CycleDay] {
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)),
            let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
        else { return [] }
        return cycleStore.getDaysInRange(start: monthStart, end: monthEnd)
    }

    private var loggedDaysCount: Int { daysThisMonth.count }

    // MARK: Wellbeing averages

    private func average(keyPath: KeyPath<CycleDay, WellbeingLevel?>) -> WellbeingLevel? {
        let values = daysThisMonth.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0) { $0 + $1.rawValue }
        let avg = sum / values.count
        return WellbeingLevel(rawValue: avg)
    }

    // MARK: Top symptoms

    private var topSymptoms: [(Symptom, Int)] {
        var counts: [Symptom: Int] = [:]
        for day in daysThisMonth {
            for symptom in day.symptoms {
                counts[symptom, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(AppTheme.Colors.accentBlue)
                    .font(.system(.callout, weight: .semibold))
                    .accessibilityHidden(true)
                Text(Date().formatted(.dateTime.month(.wide).year()))
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
                // Wellbeing row
                HStack(spacing: 0) {
                    WellbeingAveragePip(
                        label: String(localized: "Sleep"),
                        sfSymbol: "moon.stars.fill",
                        level: average(keyPath: \.sleepQuality),
                        labelText: average(keyPath: \.sleepQuality)?.sleepLabelString
                    )
                    WellbeingAveragePip(
                        label: String(localized: "Energy"),
                        sfSymbol: "bolt.fill",
                        level: average(keyPath: \.energyLevel),
                        labelText: average(keyPath: \.energyLevel)?.energyLabelString
                    )
                    WellbeingAveragePip(
                        label: String(localized: "Stress"),
                        sfSymbol: "waveform.path.ecg",
                        level: average(keyPath: \.stressLevel),
                        labelText: average(keyPath: \.stressLevel)?.stressLabelString
                    )
                }

                // Top symptoms — only shown when enough data (5+ days)
                if loggedDaysCount > 0 && loggedDaysCount < 5 {
                    Divider()
                    Text("Log 5+ days to see top symptoms.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                }
                if loggedDaysCount >= 5 && !topSymptoms.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Most frequent this month")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.mediumGrayText)
                        HStack(spacing: 8) {
                            ForEach(topSymptoms, id: \.0) { symptom, count in
                                HStack(spacing: 4) {
                                    Image(systemName: symptom.sfSymbol)
                                        .font(.system(.caption2))
                                        .foregroundStyle(AppTheme.Colors.accentBlue)
                                        .accessibilityHidden(true)
                                    Text(symptom.localizedName)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(AppTheme.Colors.deepGrayText)
                                    Text("×\(count)")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(AppTheme.Colors.mediumGrayText)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.Colors.accentBlue.opacity(0.1))
                                .cornerRadius(8)
                            }
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

    private var accessibilityLabel: String {
        var parts: [String] = [
            Date().formatted(.dateTime.month(.wide).year()),
            "\(loggedDaysCount) days logged"
        ]
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
}

// MARK: - WellbeingAveragePip

private struct WellbeingAveragePip: View {
    let label: String
    let sfSymbol: String
    let level: WellbeingLevel?
    let labelText: String?

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: sfSymbol)
                .foregroundStyle(level != nil ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText.opacity(0.35))
                .font(.system(.body))
                .accessibilityHidden(true)
            Text(verbatim: labelText ?? "—")
                .font(.system(.caption2, design: .rounded, weight: level != nil ? .semibold : .regular))
                .foregroundStyle(level != nil ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText.opacity(0.5))
            Text(verbatim: label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG || BETA
#Preview {
    let store = CycleStore()
    return MonthlySummaryView(cycleStore: store)
        .padding()
        .background(AppTheme.Colors.background)
}
#endif
