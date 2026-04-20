// MARK: - SignalEngine
//
// Pure function engine. No CycleStore dependency, no UserDefaults, no Date().
// The caller slices CycleStore days into the three windows before calling compute().
//
// Windows:
//   current  — days logged in the current calendar month
//   previous — days logged in the previous calendar month
//   baseline — days logged in the two months before that (combined)
//
// Perimenopause sub-stage is inferred from cycleLengths:
//   late = last gap between cycle starts >= 60 days, or fewer than 2 cycle lengths known
//   early = otherwise

import Foundation

// MARK: - Output types

enum SignalReadiness {
    /// Fewer than 7 days logged in the current window — show a learning message.
    case learning(daysLogged: Int)
    /// 7+ days logged — full signal available.
    case ready(SignalResult)
}

struct SignalResult {
    let stage: SignalStage
    let monthCharacter: MonthCharacter
    let dominantSymptoms: [SymptomSignal]   // ranked by thisMonth count, max 3
    let wellbeing: WellbeingSignal
    let hasBaseline: Bool                   // false = first/second month, no trend direction
}

/// Refined stage used internally by the engine — splits perimenopause.
enum SignalStage: Equatable {
    case earlyPerimenopause
    case latePerimenopause
    case menopause
    case paused
}

enum MonthCharacter: Equatable {
    case notableImprovement     // total symptom burden down >30% vs baseline avg
    case slightImprovement      // down 10–30%
    case similar                // within ±10%
    case slightlyHarder         // up 10–30%
    case notablyHarder          // up >30%
    case noComparison           // no baseline to compare against
}

struct SymptomSignal: Equatable {
    let symptom: Symptom
    let thisMonth: Int          // days logged in current window
    let baselineAvg: Double     // average days per month in baseline (0 if no baseline)
    let trend: SymptomTrend
}

enum SymptomTrend: Equatable {
    case escalating             // above baseline avg by >3 days and rising vs previous
    case stable                 // within ±3 days of baseline avg
    case improving              // below baseline avg by >3 days
    case new                    // not present in baseline at all, appeared this month
    case resolved               // present in baseline, absent this month
    case unknown                // no baseline to compare
}

struct WellbeingSignal: Equatable {
    let sleepAvg: Double?       // nil if no sleep data logged
    let energyAvg: Double?
    let stressAvg: Double?
    let sleepTrend: WellbeingTrend
    let energyTrend: WellbeingTrend
    let stressTrend: WellbeingTrend
}

enum WellbeingTrend: Equatable {
    case improving
    case stable
    case worsening
    case unknown                // no baseline or previous data
}

// MARK: - Engine

enum SignalEngine {

    private static let minDaysForSignal = 7
    /// Days-gap between cycle starts that indicates late perimenopause.
    private static let latePeriGapDays  = 60

    // MARK: Public entry point

    static func compute(
        current:      [CycleDay],
        previous:     [CycleDay],
        baseline:     [CycleDay],
        stage:        LifeStage,
        cycleLengths: [Int]
    ) -> SignalReadiness {
        let daysLogged = current.count
        guard daysLogged >= minDaysForSignal else {
            return .learning(daysLogged: daysLogged)
        }

        let signalStage = resolveStage(stage: stage, cycleLengths: cycleLengths)
        let hasBaseline = !baseline.isEmpty

        let dominantSymptoms = computeSymptomSignals(
            current: current,
            baseline: baseline,
            previous: previous,
            hasBaseline: hasBaseline
        )

        let wellbeing = computeWellbeingSignal(
            current: current,
            previous: previous,
            baseline: baseline,
            hasBaseline: hasBaseline
        )

        let monthCharacter = computeMonthCharacter(
            current: current,
            baseline: baseline,
            hasBaseline: hasBaseline
        )

        return .ready(SignalResult(
            stage: signalStage,
            monthCharacter: monthCharacter,
            dominantSymptoms: dominantSymptoms,
            wellbeing: wellbeing,
            hasBaseline: hasBaseline
        ))
    }

    // MARK: Stage resolution

    private static func resolveStage(stage: LifeStage, cycleLengths: [Int]) -> SignalStage {
        switch stage {
        case .menopause:
            return .menopause
        case .paused:
            return .paused
        case .perimenopause:
            return isLatePerimenopause(cycleLengths: cycleLengths)
                ? .latePerimenopause
                : .earlyPerimenopause
        case .regular, .irregular:
            // Signal is not shown for regular/irregular — caller guards this,
            // but return a sensible fallback rather than crash.
            return .earlyPerimenopause
        }
    }

    /// Late perimenopause: last known cycle gap >= 60 days, or fewer than 2 lengths known.
    private static func isLatePerimenopause(cycleLengths: [Int]) -> Bool {
        guard cycleLengths.count >= 2 else { return true }
        let lastGap = cycleLengths.last ?? 0
        return lastGap >= latePeriGapDays
    }

    // MARK: Symptom signals

    private static func computeSymptomSignals(
        current:     [CycleDay],
        baseline:    [CycleDay],
        previous:    [CycleDay],
        hasBaseline: Bool
    ) -> [SymptomSignal] {

        // Count days per symptom in each window.
        // Baseline spans ~2 months — normalise to per-month average.
        let currentCounts  = symptomDayCounts(current)
        let previousCounts = symptomDayCounts(previous)
        let baselineCounts = symptomDayCounts(baseline)

        // Baseline covers 2 months worth of days — avg per month = count / 2
        let baselineAvgs: [Symptom: Double] = hasBaseline
            ? baselineCounts.mapValues { Double($0) / 2.0 }
            : [:]

        // Collect all symptoms that appear in current month.
        let activeSymptoms = currentCounts.keys.sorted {
            (currentCounts[$0] ?? 0) > (currentCounts[$1] ?? 0)
        }

        let signals: [SymptomSignal] = activeSymptoms.map { symptom in
            let thisMonth   = currentCounts[symptom] ?? 0
            let prevMonth   = previousCounts[symptom] ?? 0
            let baselineAvg = baselineAvgs[symptom] ?? 0.0

            let trend: SymptomTrend
            if !hasBaseline {
                trend = .unknown
            } else if baselineAvg == 0 && thisMonth > 0 {
                trend = .new
            } else {
                let delta = Double(thisMonth) - baselineAvg
                if delta > 3 && thisMonth > prevMonth {
                    trend = .escalating
                } else if delta < -3 {
                    trend = .improving
                } else {
                    trend = .stable
                }
            }

            return SymptomSignal(
                symptom: symptom,
                thisMonth: thisMonth,
                baselineAvg: baselineAvg,
                trend: trend
            )
        }

        // Also surface resolved symptoms (in baseline, absent this month).
        let resolvedSignals: [SymptomSignal] = hasBaseline
            ? baselineAvgs.keys
                .filter { (currentCounts[$0] ?? 0) == 0 && (baselineAvgs[$0] ?? 0) > 2 }
                .map { symptom in
                    SymptomSignal(
                        symptom: symptom,
                        thisMonth: 0,
                        baselineAvg: baselineAvgs[symptom] ?? 0,
                        trend: .resolved
                    )
                }
            : []

        // Return top 3 active symptoms by frequency, then resolved ones after.
        let top3Active   = Array(signals.prefix(3))
        let topResolved  = resolvedSignals
            .sorted { $0.baselineAvg > $1.baselineAvg }
            .prefix(1)  // surface at most 1 resolved symptom

        return top3Active + topResolved
    }

    private static func symptomDayCounts(_ days: [CycleDay]) -> [Symptom: Int] {
        var counts: [Symptom: Int] = [:]
        for day in days {
            for symptom in day.symptoms {
                counts[symptom, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: Wellbeing signal

    private static func computeWellbeingSignal(
        current:     [CycleDay],
        previous:    [CycleDay],
        baseline:    [CycleDay],
        hasBaseline: Bool
    ) -> WellbeingSignal {
        let currentSleep  = average(current,  \.sleepQuality)
        let currentEnergy = average(current,  \.energyLevel)
        let currentStress = average(current,  \.stressLevel)

        let baselineSleep  = hasBaseline ? average(baseline, \.sleepQuality)  : nil
        let baselineEnergy = hasBaseline ? average(baseline, \.energyLevel)   : nil
        let baselineStress = hasBaseline ? average(baseline, \.stressLevel)   : nil

        return WellbeingSignal(
            sleepAvg:    currentSleep,
            energyAvg:   currentEnergy,
            stressAvg:   currentStress,
            sleepTrend:  wellbeingTrend(current: currentSleep,  baseline: baselineSleep,  higherIsBetter: true),
            energyTrend: wellbeingTrend(current: currentEnergy, baseline: baselineEnergy, higherIsBetter: true),
            stressTrend: wellbeingTrend(current: currentStress, baseline: baselineStress, higherIsBetter: false)
        )
    }

    private static func average(_ days: [CycleDay], _ keyPath: KeyPath<CycleDay, WellbeingLevel?>) -> Double? {
        let values = days.compactMap { $0[keyPath: keyPath]?.rawValue }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// For sleep and energy, higher rawValue = better.
    /// For stress, higher rawValue = worse — so invert the trend direction.
    private static func wellbeingTrend(
        current:        Double?,
        baseline:       Double?,
        higherIsBetter: Bool
    ) -> WellbeingTrend {
        guard let c = current, let b = baseline else { return .unknown }
        let delta = c - b
        let threshold = 0.5  // half a level on the 0–4 scale
        if abs(delta) < threshold { return .stable }
        let improving = higherIsBetter ? delta > 0 : delta < 0
        return improving ? .improving : .worsening
    }

    // MARK: Month character

    /// Overall character based on total symptom burden (days affected) vs baseline average.
    private static func computeMonthCharacter(
        current:     [CycleDay],
        baseline:    [CycleDay],
        hasBaseline: Bool
    ) -> MonthCharacter {
        guard hasBaseline else { return .noComparison }

        let currentBurden  = Double(totalSymptomDays(current))
        // Baseline spans ~2 months — avg per month
        let baselineBurden = Double(totalSymptomDays(baseline)) / 2.0

        guard baselineBurden > 0 else {
            return currentBurden > 0 ? .slightlyHarder : .similar
        }

        let ratio = currentBurden / baselineBurden
        switch ratio {
        case ..<0.70: return .notableImprovement
        case 0.70..<0.90: return .slightImprovement
        case 0.90...1.10: return .similar
        case 1.10...1.30: return .slightlyHarder
        default:          return .notablyHarder
        }
    }

    private static func totalSymptomDays(_ days: [CycleDay]) -> Int {
        days.filter { !$0.symptoms.isEmpty }.count
    }
}
