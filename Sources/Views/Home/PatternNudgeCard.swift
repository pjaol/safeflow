import SwiftUI

/// A dismissible card that surfaces a pattern or comfort suggestion based on logged data.
///
/// Two kinds of nudge:
///   - Health pattern: unusual cycle characteristics after 3+ cycles (very short, very long,
///     high variability, long period). Suggests talking to a doctor — non-alarmist framing.
///   - Comfort suggestion: cramps + heavy flow logged consistently. Surfaces factual
///     comfort information (heat, ibuprofen, magnesium).
///
/// Each nudge has a stable `id`. Once dismissed, it is stored in UserDefaults so it
/// never re-appears for the same pattern.
struct PatternNudgeCard: View {
    let nudge: CycleNudge
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: nudge.sfSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.deepGrayText)

            VStack(alignment: .leading, spacing: 6) {
                Text(nudge.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                Text(nudge.body)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(nudge.backgroundColor)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.patternNudgeCard.\(nudge.id)")
    }
}

// MARK: - CycleNudge

struct CycleNudge: Identifiable, Equatable {
    let id: String
    let sfSymbol: String
    let title: String
    let body: String
    let backgroundColor: Color

    // MARK: - Factory

    /// Evaluates logged cycle data and returns the highest-priority undismissed nudge, if any.
    static func evaluate(
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        engine: CyclePredictionEngine,
        dismissed: Set<String>
    ) -> CycleNudge? {
        let periodStarts = engine.extractPeriodStarts(from: cycleDays)
        let lengths = engine.cycleLengths(from: periodStarts)

        // Need at least 3 complete cycles before surfacing health pattern nudges
        if lengths.count >= 3 {
            if let nudge = healthPatternNudge(lengths: lengths, cycleDays: cycleDays, engine: engine, dismissed: dismissed) {
                return nudge
            }
        }

        // Comfort suggestion — only needs 2+ logged periods with consistent heavy cramps
        if periodStarts.count >= 2 {
            if let nudge = comfortNudge(cycleDays: cycleDays, dismissed: dismissed) {
                return nudge
            }
        }

        return nil
    }

    // MARK: - Health Pattern Nudges

    private static func healthPatternNudge(
        lengths: [Int],
        cycleDays: [CycleDay],
        engine: CyclePredictionEngine,
        dismissed: Set<String>
    ) -> CycleNudge? {
        let avg = lengths.reduce(0, +) / lengths.count
        let variability = engine.cycleVariability(from: lengths) ?? 0

        // Check patterns in priority order — return first undismissed match
        let candidates: [CycleNudge] = [
            shortCycleNudge(avg: avg),
            longCycleNudge(avg: avg),
            highVariabilityNudge(variability: variability),
            longPeriodNudge(cycleDays: cycleDays, engine: engine),
        ].compactMap { $0 }

        return candidates.first { !dismissed.contains($0.id) }
    }

    private static func shortCycleNudge(avg: Int) -> CycleNudge? {
        guard avg < 21 else { return nil }
        return CycleNudge(
            id: "pattern.shortCycle",
            sfSymbol: "calendar",
            title: "Your cycles are running short",
            body: "Your average cycle is around \(avg) days. Cycles shorter than 21 days are worth mentioning to a doctor — it's a common and treatable pattern.",
            backgroundColor: Color(hex: "FEF3C7")
        )
    }

    private static func longCycleNudge(avg: Int) -> CycleNudge? {
        guard avg > 35 else { return nil }
        return CycleNudge(
            id: "pattern.longCycle",
            sfSymbol: "calendar",
            title: "Your cycles are running long",
            body: "Your average cycle is around \(avg) days. Cycles over 35 days can have a few different causes — a doctor can help figure out what's going on.",
            backgroundColor: Color(hex: "FEF3C7")
        )
    }

    private static func highVariabilityNudge(variability: Double) -> CycleNudge? {
        guard variability > 7 else { return nil }
        return CycleNudge(
            id: "pattern.highVariability",
            sfSymbol: "chart.line.uptrend.xyaxis",
            title: "Your cycle length varies a lot",
            body: "Your cycles vary by more than a week from month to month. This is fairly common but worth a chat with a doctor if it's been going on a while.",
            backgroundColor: Color(hex: "FEF3C7")
        )
    }

    private static func longPeriodNudge(cycleDays: [CycleDay], engine: CyclePredictionEngine) -> CycleNudge? {
        // Check if recent periods consistently last more than 7 days
        let periodStarts = engine.extractPeriodStarts(from: cycleDays)
        guard periodStarts.count >= 2 else { return nil }

        let recentStarts = periodStarts.suffix(3)
        let calendar = Calendar.current
        let flowDays = cycleDays.filter { $0.flow != nil && $0.flow != .spotting }

        var longPeriodCount = 0
        for (i, start) in recentStarts.enumerated() {
            let end = i + 1 < recentStarts.count
                ? recentStarts[recentStarts.index(recentStarts.startIndex, offsetBy: i + 1)]
                : calendar.date(byAdding: .day, value: 10, to: start) ?? start
            let daysInPeriod = flowDays.filter { $0.date >= start && $0.date < end }.count
            if daysInPeriod > 7 { longPeriodCount += 1 }
        }

        guard longPeriodCount >= 2 else { return nil }
        return CycleNudge(
            id: "pattern.longPeriod",
            sfSymbol: "stethoscope",
            title: "Your periods are running long",
            body: "Periods consistently over 7 days are worth mentioning to a doctor. There are several common, treatable causes.",
            backgroundColor: Color(hex: "FEF3C7")
        )
    }

    // MARK: - Comfort Nudges

    private static func comfortNudge(cycleDays: [CycleDay], dismissed: Set<String>) -> CycleNudge? {
        let id = "comfort.crampsHeavy"
        guard !dismissed.contains(id) else { return nil }

        // Count recent period days with both cramps and heavy/medium flow
        let periodFlowDays = cycleDays.filter {
            ($0.flow == .heavy || $0.flow == .medium) && $0.symptoms.contains(.cramps)
        }
        guard periodFlowDays.count >= 3 else { return nil }

        return CycleNudge(
            id: id,
            sfSymbol: "thermometer.medium",
            title: "You've been logging cramps",
            body: "A few things that can help: heat on your lower abdomen, ibuprofen taken with food at the first sign (not after), and magnesium-rich foods like dark chocolate and nuts.",
            backgroundColor: Color(hex: "FDE8EF")
        )
    }
}

// MARK: - Dismissed Nudge Storage

/// Persists dismissed nudge IDs so they never re-appear.
struct DismissedNudges {
    private static let key = "dismissedNudgeIDs"

    static func load() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    static func dismiss(_ id: String) {
        var current = load()
        current.insert(id)
        UserDefaults.standard.set(Array(current), forKey: key)
    }
}

#Preview {
    VStack(spacing: 12) {
        PatternNudgeCard(
            nudge: CycleNudge(
                id: "pattern.shortCycle",
                sfSymbol: "calendar",
                title: "Your cycles are running short",
                body: "Your average cycle is around 19 days. Cycles shorter than 21 days are worth mentioning to a doctor.",
                backgroundColor: Color(hex: "FEF3C7")
            ),
            onDismiss: {}
        )
        PatternNudgeCard(
            nudge: CycleNudge(
                id: "comfort.crampsHeavy",
                sfSymbol: "thermometer.medium",
                title: "You've been logging cramps",
                body: "A few things that can help: heat on your lower abdomen, ibuprofen taken with food at the first sign, and magnesium-rich foods.",
                backgroundColor: Color(hex: "FDE8EF")
            ),
            onDismiss: {}
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
}
