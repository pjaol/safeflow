import SwiftUI

/// Displays the current cycle phase, day number, and next period prediction range.
/// Receives pre-computed values so it is a pure display component with no store dependency.
struct CyclePhaseCard: View {
    let phase: CyclePhase?
    let cycleDay: Int?
    let predictionRange: (earliest: Date, latest: Date)?
    let averageCycleLength: Int?
    let hasEnoughData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let phase {
                phaseHeader(phase: phase)
                Divider()
                predictionRow
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Metrics.cardPadding)
        .background(cardBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.cyclePhaseCard")
    }

    // MARK: - Sub-views

    private func phaseHeader(phase: CyclePhase) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(phase.displayName)
                        .font(AppTheme.Typography.headlineFont)
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                        .accessibilityIdentifier("home.cyclePhaseCard.phaseName")

                    if let day = cycleDay {
                        Text("· Day \(day)")
                            .font(.system(.title, design: .rounded, weight: .regular))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .accessibilityIdentifier("home.cyclePhaseCard.cycleDay")
                    }
                }

                Text(phase.phaseDescription)
                    .font(AppTheme.Typography.captionFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            phaseIndicator(phase: phase)
        }
    }

    private func phaseIndicator(phase: CyclePhase) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.forPhase(phase.themeColorName).opacity(0.3))
                .frame(width: 48, height: 48)
            Circle()
                .fill(AppTheme.Colors.forPhase(phase.themeColorName))
                .frame(width: 28, height: 28)
        }
    }

    private var predictionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let range = predictionRange {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                    Text("Next period \(formattedRange(range))")
                        .font(AppTheme.Typography.captionFont)
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .accessibilityIdentifier("home.cyclePhaseCard.predictionRange")
                }

                if !hasEnoughData {
                    Text("Building accuracy — log more periods for a personalised range")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Log your first period to see predictions")
                    .font(AppTheme.Typography.captionFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }

            if let length = averageCycleLength {
                Text("Average cycle: \(length) days")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cycle Tracking")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            Text("Log your first period to see your cycle phase and predictions.")
                .font(AppTheme.Typography.captionFont)
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardBackground: Color {
        if let phase {
            return AppTheme.Colors.forPhase(phase.themeColorName).opacity(0.15)
        }
        return AppTheme.Colors.secondaryBackground
    }

    // MARK: - Date Formatting

    private func formattedRange(_ range: (earliest: Date, latest: Date)) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDate(range.earliest, equalTo: range.latest, toGranularity: .month) {
            formatter.dateFormat = "d"
            let endStr = formatter.string(from: range.latest)
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: range.earliest)
            return "\(startStr)–\(endStr)"
        } else {
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: range.earliest)
            let endStr = formatter.string(from: range.latest)
            return "\(startStr) – \(endStr)"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CyclePhaseCard(
            phase: .follicular,
            cycleDay: 11,
            predictionRange: (
                earliest: Calendar.current.date(byAdding: .day, value: 8, to: Date())!,
                latest: Calendar.current.date(byAdding: .day, value: 13, to: Date())!
            ),
            averageCycleLength: 28,
            hasEnoughData: true
        )
        CyclePhaseCard(
            phase: .menstrual,
            cycleDay: 2,
            predictionRange: nil,
            averageCycleLength: nil,
            hasEnoughData: false
        )
        CyclePhaseCard(
            phase: nil,
            cycleDay: nil,
            predictionRange: nil,
            averageCycleLength: nil,
            hasEnoughData: false
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
}
