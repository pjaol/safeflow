import SwiftUI

// MARK: - UnexpectedBleedingCard

/// Shown on the home screen when a flow event is logged in menopause or paused stage.
/// Provides a gentle acknowledgement and a dismiss action.
struct UnexpectedBleedingCard: View {
    let lifeStage: LifeStage
    let onDismiss: () -> Void

    private var subtitle: LocalizedStringKey {
        lifeStage == .paused
            ? "We've noted this. You can log more detail in your diary."
            : "Worth noting for your next appointment."
    }

    private var subtitleString: String {
        lifeStage == .paused
            ? String(localized: "We've noted this. You can log more detail in your diary.")
            : String(localized: "Worth noting for your next appointment.")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryPink)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unexpected bleeding logged")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.Colors.secondaryBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryPink.opacity(0.1))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unexpected bleeding logged. \(subtitleString)")
        .accessibilityIdentifier("home.unexpectedBleedingCard")
    }
}

// MARK: - SymptomSnapshotCard

/// Shows a 30-day count of vasomotor and musculoskeletal symptoms for perimenopause/menopause users.
struct SymptomSnapshotCard: View {
    let cycleStore: CycleStore

    private var windowDays: [CycleDay] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -29, to: end) ?? end
        return cycleStore.getDaysInRange(start: start, end: end)
    }

    private func count(for category: SymptomCategory) -> Int {
        windowDays.filter { day in
            day.symptoms.contains(where: { $0.category == category })
        }.count
    }

    private var hasData: Bool {
        count(for: .vasomotor) > 0 || count(for: .musculoskeletal) > 0
    }

    var body: some View {
        if hasData {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(AppTheme.Colors.dartEnergy)
                        .font(.system(.callout, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Last 30 days")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.deepGrayText)
                }

                HStack(spacing: 16) {
                    SymptomCountRow(
                        label: "Hot Flashes",
                        sfSymbol: "thermometer.sun.fill",
                        count: count(for: .vasomotor),
                        color: AppTheme.Colors.dartPain
                    )
                    Divider().frame(height: 36)
                    SymptomCountRow(
                        label: "Joint Pain",
                        sfSymbol: "figure.strengthtraining.traditional",
                        count: count(for: .musculoskeletal),
                        color: AppTheme.Colors.dartEnergy
                    )
                }
            }
            .padding(AppTheme.Metrics.cardPadding)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Symptom snapshot, last 30 days. Hot flashes: \(count(for: .vasomotor)) days. Joint pain: \(count(for: .musculoskeletal)) days.")
            .accessibilityIdentifier("home.symptomSnapshotCard")
        }
    }
}

private struct SymptomCountRow: View {
    let label: LocalizedStringKey
    let sfSymbol: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sfSymbol)
                .foregroundStyle(color)
                .font(.system(.body))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }
        }
    }
}

// MARK: - BleedHistoryCard

/// For perimenopause users: shows the dates of the last few logged bleeds instead of cycle predictions.
struct BleedHistoryCard: View {
    let cycleStore: CycleStore

    private var recentBleeds: [CycleDay] {
        cycleStore.getAllDays()
            .filter { $0.flow != nil }
            .sorted { $0.date > $1.date }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(AppTheme.Colors.secondaryPink)
                    .font(.system(.callout, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Recent bleeds")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
            }

            if recentBleeds.isEmpty {
                Text("No bleeds logged yet.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recentBleeds) { day in
                        HStack(spacing: 8) {
                            Image(systemName: day.flow?.sfSymbol ?? "drop.fill")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.secondaryPink)
                                .frame(width: 16)
                                .accessibilityHidden(true)
                            Text(day.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.deepGrayText)
                            Spacer()
                            if let flow = day.flow {
                                Text(flow.localizedName)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
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
        .accessibilityLabel(bleedHistoryAccessibilityLabel)
        .accessibilityIdentifier("home.bleedHistoryCard")
    }

    private var bleedHistoryAccessibilityLabel: String {
        if recentBleeds.isEmpty {
            return String(localized: "Recent bleeds. No bleeds logged yet.")
        }
        let dates = recentBleeds.map { day in
            day.date.formatted(.dateTime.month(.wide).day().year())
        }.joined(separator: ", ")
        return String(localized: "Recent bleeds: \(dates)")
    }
}

// MARK: - PausedSummaryCard

/// For paused-stage users: shows a simple daily wellbeing summary instead of cycle ring/predictions.
struct PausedSummaryCard: View {
    let cycleStore: CycleStore

    private var today: CycleDay? { cycleStore.getCurrentDay() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(AppTheme.Colors.primaryBlue)
                    .font(.system(.callout, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Tracking paused")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
            }

            if let day = today {
                HStack(spacing: 16) {
                    WellbeingSummaryPip(
                        label: "Sleep",
                        sfSymbol: "moon.stars.fill",
                        level: day.sleepQuality,
                        labelText: day.sleepQuality?.sleepLabelString
                    )
                    WellbeingSummaryPip(
                        label: "Energy",
                        sfSymbol: "bolt.fill",
                        level: day.energyLevel,
                        labelText: day.energyLevel?.energyLabelString
                    )
                    WellbeingSummaryPip(
                        label: "Stress",
                        sfSymbol: "waveform.path.ecg",
                        level: day.stressLevel,
                        labelText: day.stressLevel?.stressLabelString
                    )
                }
            } else {
                Text("Start by logging how you feel today.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pausedAccessibilityLabel)
        .accessibilityIdentifier("home.pausedSummaryCard")
    }

    private var pausedAccessibilityLabel: String {
        guard let day = today else {
            return String(localized: "Tracking paused. Start by logging how you feel today.")
        }
        let sleep = day.sleepQuality.map { "Sleep: \($0.sleepLabelString)" } ?? "Sleep: not logged"
        let energy = day.energyLevel.map { "Energy: \($0.energyLabelString)" } ?? "Energy: not logged"
        let stress = day.stressLevel.map { "Stress: \($0.stressLabelString)" } ?? "Stress: not logged"
        return "Tracking paused. Today — \(sleep), \(energy), \(stress)."
    }
}

private struct WellbeingSummaryPip: View {
    let label: LocalizedStringKey
    let sfSymbol: String
    let level: WellbeingLevel?
    let labelText: String?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: sfSymbol)
                .foregroundStyle(level != nil ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText.opacity(0.4))
                .font(.system(.callout))
                .accessibilityHidden(true)
            Text(labelText ?? "—")
                .font(.system(.caption2, design: .rounded, weight: level != nil ? .semibold : .regular))
                .foregroundStyle(level != nil ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText.opacity(0.5))
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
        }
        .frame(maxWidth: .infinity)
    }
}
