// MARK: - SignalWindowResolver
//
// Determines the correct time windows for the SignalEngine based on whether the
// user is in sentinel mode (a period start exists within 90 days) or rolling mode
// (no period in 90+ days, typical of late perimenopause / menopause).
//
// Sentinel mode  — current = days since last period start
//                  baseline = two complete prior cycles (start-to-start bounded)
//                  label    = "This cycle · Day N"
//
// Rolling mode   — current  = last 30 days
//                  baseline = days 31–90
//                  label    = "Last 30 days"
//
// The SignalEngine receives the same three arrays either way — it has no knowledge
// of which mode produced them.
//
// Pure function. No CycleStore dependency, no UserDefaults, no side effects.
// The caller passes pre-fetched days and today's date.

import Foundation

// MARK: - Output

enum SignalWindowLabel: Equatable {
    /// Sentinel mode: a period was detected within `sentinelDays` of today.
    case thisCycle(dayNumber: Int)
    /// Rolling mode: no recent period detected.
    case rolling(days: Int)
}

struct SignalWindow {
    let current:  [CycleDay]
    let baseline: [CycleDay]
    let label:    SignalWindowLabel

    /// True when there is enough data in the current window for the engine to produce
    /// a signal (mirrors SignalEngine's 7-day minimum).
    var hasEnoughData: Bool { current.count >= 7 }
}

// MARK: - Resolver

enum SignalWindowResolver {

    /// Days without a period start before switching from sentinel to rolling mode.
    static let sentinelTimeoutDays = 90
    /// Width of the rolling current window (days).
    static let rollingCurrentDays  = 30
    /// Width of the rolling baseline window (days, immediately before current).
    static let rollingBaselineDays = 60

    // MARK: Public entry point

    /// Resolves the appropriate signal windows for the given set of logged days.
    ///
    /// - Parameters:
    ///   - allDays: All logged `CycleDay` objects. Order is irrelevant.
    ///   - today:   Reference date. Pass `Date()` in production; injectable for tests.
    static func resolve(allDays: [CycleDay], today: Date = Date()) -> SignalWindow {
        let cal = Calendar.current

        // Anchor to the most recent logged day, capped at today.
        // This means historical scenario data (e.g. Jan–Apr 2025 loaded in Apr 2026)
        // resolves windows relative to when the data ends, not the current clock date.
        let mostRecentLog = allDays.max(by: { $0.date < $1.date })?.date ?? today
        let anchor = cal.startOfDay(for: min(mostRecentLog, today))

        // Extract period starts using the same grouping logic as CyclePredictionEngine.
        let periodStarts = extractPeriodStarts(from: allDays, cal: cal)
            .sorted()

        // Find the most recent period start that is on or before the anchor.
        guard let lastStart = periodStarts.last(where: { $0 <= anchor }) else {
            // No periods at all — rolling mode from anchor.
            return rollingWindow(allDays: allDays, anchor: anchor, cal: cal)
        }

        let daysSinceLastStart = cal.dateComponents([.day], from: lastStart, to: anchor).day ?? 0

        if daysSinceLastStart <= sentinelTimeoutDays {
            return sentinelWindow(
                allDays:      allDays,
                lastStart:    lastStart,
                periodStarts: periodStarts,
                today:        anchor,
                cal:          cal
            )
        } else {
            return rollingWindow(allDays: allDays, anchor: anchor, cal: cal)
        }
    }

    // MARK: - Sentinel window

    private static func sentinelWindow(
        allDays:      [CycleDay],
        lastStart:    Date,
        periodStarts: [Date],
        today:        Date,
        cal:          Calendar
    ) -> SignalWindow {
        let dayNumber = (cal.dateComponents([.day], from: lastStart, to: today).day ?? 0) + 1

        // Current = from last period start up to and including today
        let current = allDays.filter { day in
            let d = cal.startOfDay(for: day.date)
            return d >= lastStart && d <= today
        }

        // Baseline = all days in the two complete cycles immediately before lastStart.
        // A complete cycle is bounded [periodStarts[n], periodStarts[n+1]).
        let priorStarts = periodStarts.filter { $0 < lastStart }
        let baseline: [CycleDay]

        if priorStarts.count >= 2 {
            // Two most recent prior starts
            let b1Start = priorStarts[priorStarts.count - 2]
            let b2Start = priorStarts[priorStarts.count - 1] // = one cycle before lastStart
            baseline = allDays.filter { day in
                let d = cal.startOfDay(for: day.date)
                return d >= b1Start && d < lastStart
            }
            _ = b2Start // used implicitly via the range b1Start..<lastStart
        } else if priorStarts.count == 1 {
            // Only one prior cycle available — use it as baseline
            let b1Start = priorStarts[0]
            baseline = allDays.filter { day in
                let d = cal.startOfDay(for: day.date)
                return d >= b1Start && d < lastStart
            }
        } else {
            baseline = []
        }

        return SignalWindow(
            current:  current,
            baseline: baseline,
            label:    .thisCycle(dayNumber: dayNumber)
        )
    }

    // MARK: - Rolling window

    private static func rollingWindow(
        allDays: [CycleDay],
        anchor:  Date,
        cal:     Calendar
    ) -> SignalWindow {
        // current  = [anchor - 29 days, anchor]  (30 days inclusive)
        // baseline = [anchor - 89 days, anchor - 30 days]  (60 days)
        guard
            let currentStart  = cal.date(byAdding: .day, value: -(rollingCurrentDays - 1), to: anchor),
            let baselineStart = cal.date(byAdding: .day, value: -(rollingCurrentDays + rollingBaselineDays - 1), to: anchor),
            let baselineEnd   = cal.date(byAdding: .day, value: -rollingCurrentDays, to: anchor)
        else {
            return SignalWindow(current: [], baseline: [], label: .rolling(days: rollingCurrentDays))
        }

        let current = allDays.filter { day in
            let d = cal.startOfDay(for: day.date)
            return d >= currentStart && d <= anchor
        }

        let baseline = allDays.filter { day in
            let d = cal.startOfDay(for: day.date)
            return d >= baselineStart && d <= baselineEnd
        }

        return SignalWindow(
            current:  current,
            baseline: baseline,
            label:    .rolling(days: rollingCurrentDays)
        )
    }

    // MARK: - Period start extraction
    //
    // Mirrors CyclePredictionEngine.extractPeriodStarts — duplicated here so this
    // resolver has no dependency on CycleStore or the engine. Keep in sync if the
    // engine's grouping logic changes.

    private static func extractPeriodStarts(from days: [CycleDay], cal: Calendar) -> [Date] {
        let flowDays = days
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }
        guard !flowDays.isEmpty else { return [] }

        let gapDays = 3
        var runs: [[CycleDay]] = []
        var currentRun: [CycleDay] = [flowDays[0]]

        for i in 1..<flowDays.count {
            let gap = cal.dateComponents([.day], from: flowDays[i - 1].date, to: flowDays[i].date).day ?? 0
            if gap <= gapDays {
                currentRun.append(flowDays[i])
            } else {
                runs.append(currentRun)
                currentRun = [flowDays[i]]
            }
        }
        runs.append(currentRun)

        return runs.compactMap { run -> Date? in
            let nonSpotting = run.filter { $0.flow != .spotting }
            guard nonSpotting.count >= 2 else { return nil }
            return cal.startOfDay(for: run[0].date)
        }
    }
}
