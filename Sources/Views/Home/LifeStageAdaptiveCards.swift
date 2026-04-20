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

/// For perimenopause users: shows the last few cycles as (start date, duration) rows.
/// One row per cycle — not per day — so the dashboard shows pattern, not granular log detail.
/// Hidden entirely when no cycles have been logged yet.
struct BleedHistoryCard: View {
    let cycleStore: CycleStore
    @Environment(\.locale) private var locale

    private var cycles: [(start: Date, days: Int)] {
        cycleStore.recentCycles(limit: 3)
    }

    var body: some View {
        if cycles.isEmpty { return AnyView(EmptyView()) }
        return AnyView(cardBody)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(AppTheme.Colors.secondaryPink)
                    .font(.system(.callout, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Cycle history")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepGrayText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(cycles.enumerated()), id: \.offset) { index, cycle in
                    HStack(spacing: 0) {
                        Text(cycle.start.formatted(.dateTime.month(.abbreviated).year().locale(locale)))
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(index == 0 ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText)
                        Spacer()
                        Text("\(cycle.days) \(cycle.days == 1 ? "day" : "days")")
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.mediumGrayText)
                    }
                    if index < cycles.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cycleHistoryAccessibilityLabel)
        .accessibilityIdentifier("home.bleedHistoryCard")
    }

    private var cycleHistoryAccessibilityLabel: String {
        let rows = cycles.map { cycle in
            "\(cycle.start.formatted(.dateTime.month(.wide).year())), \(cycle.days) \(cycle.days == 1 ? "day" : "days")"
        }.joined(separator: ". ")
        return "Cycle history. \(rows)"
    }
}

// MARK: - PausedSummaryCard

/// For paused-stage users: shows a simple card with a prompt to log how they feel.
struct PausedSummaryCard: View {
    let cycleStore: CycleStore

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

            Text("Log how you feel using the daily tracker.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracking paused. Log how you feel using the daily tracker.")
        .accessibilityIdentifier("home.pausedSummaryCard")
    }
}
