import Foundation

/// Pure, stateless prediction engine.
///
/// Accepts `[CycleDay]`, optional seed data, and a reference date, and returns
/// all cycle intelligence the app needs. Has no storage, no actors, and no
/// `Date()` calls — the caller supplies the current date, making every method
/// fully deterministic and trivially unit-testable.
struct CyclePredictionEngine {

    // MARK: - Constants

    /// Population mean cycle length used as a prior when individual data is sparse.
    static let populationMeanCycleLength: Double = 29.1

    /// The luteal phase is clinically stable at ~14 days regardless of cycle length.
    static let lutealPhaseLength: Int = 14

    /// Maximum number of recent cycles used for the weighted average.
    static let maxCyclesForAverage: Int = 6

    /// Minimum period duration (days with non-spotting flow) to count as a real period.
    static let minimumPeriodDays: Int = 2

    /// Gap in days between two flow days that signals a new period has started.
    static let periodGapDays: Int = 3

    // MARK: - Period Detection

    /// Extracts confirmed period start dates from logged cycle days.
    ///
    /// A period is defined as a run of flow days where:
    /// - At least `minimumPeriodDays` days exist in the run, AND
    /// - At least one day is not `.spotting`
    ///
    /// This prevents isolated spotting from being counted as a period start.
    func extractPeriodStarts(from days: [CycleDay]) -> [Date] {
        let calendar = Calendar.current
        let flowDays = days
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }

        guard !flowDays.isEmpty else { return [] }

        // Group consecutive flow days into runs (gap ≤ periodGapDays)
        var runs: [[CycleDay]] = []
        var currentRun: [CycleDay] = [flowDays[0]]

        for i in 1..<flowDays.count {
            let gap = calendar.dateComponents([.day], from: flowDays[i - 1].date, to: flowDays[i].date).day ?? 0
            if gap <= Self.periodGapDays {
                currentRun.append(flowDays[i])
            } else {
                runs.append(currentRun)
                currentRun = [flowDays[i]]
            }
        }
        runs.append(currentRun)

        // A run qualifies as a period if it has enough days with real flow
        return runs.compactMap { run -> Date? in
            let nonSpottingDays = run.filter { $0.flow != .spotting }
            guard nonSpottingDays.count >= Self.minimumPeriodDays else { return nil }
            return calendar.startOfDay(for: run[0].date)
        }
    }

    // MARK: - Cycle Length

    /// Returns individual cycle lengths in days between consecutive period starts.
    func cycleLengths(from periodStarts: [Date]) -> [Int] {
        let calendar = Calendar.current
        return zip(periodStarts, periodStarts.dropFirst())
            .compactMap { calendar.dateComponents([.day], from: $0, to: $1).day }
            .filter { $0 > 0 }
    }

    /// Weighted moving average over the last `maxCyclesForAverage` cycles.
    ///
    /// More recent cycles receive higher weight (linear ramp: oldest = weight 1,
    /// newest = weight N). Falls back to `seedPrior` (user-supplied from onboarding)
    /// when fewer than 2 complete cycles are available, or to the population prior
    /// if no seed is available.
    func weightedAverageCycleLength(from lengths: [Int], seedPrior: Double? = nil) -> Double {
        let recent = Array(lengths.suffix(Self.maxCyclesForAverage))
        guard recent.count >= 2 else { return seedPrior ?? Self.populationMeanCycleLength }

        let weights = (1...recent.count).map { Double($0) }
        let weightedSum = zip(recent, weights).reduce(0.0) { $0 + Double($1.0) * $1.1 }
        let weightTotal = weights.reduce(0, +)
        return weightedSum / weightTotal
    }

    /// Standard deviation of cycle lengths. Returns `nil` when fewer than 2 lengths exist.
    func cycleVariability(from lengths: [Int]) -> Double? {
        let recent = Array(lengths.suffix(Self.maxCyclesForAverage))
        guard recent.count >= 2 else { return nil }

        let mean = recent.reduce(0.0) { $0 + Double($1) } / Double(recent.count)
        let variance = recent.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(recent.count - 1)
        return sqrt(variance)
    }

    // MARK: - Prediction

    /// Predicts the next period start as a single date. Uses the weighted average
    /// and falls back to the population prior when data is sparse.
    func predictNextPeriod(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> Date? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let periodStarts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: periodStarts)
        let seedPrior = seedData.map { Double($0.typicalCycleLength) }
        let avgLength = weightedAverageCycleLength(from: lengths, seedPrior: seedPrior)

        // Prefer logged period starts; fall back to seed data
        let lastStart: Date
        if let logged = periodStarts.filter({ $0 <= todayStart }).last {
            lastStart = logged
        } else if let seed = seedData {
            lastStart = calendar.startOfDay(for: seed.lastPeriodStartDate)
        } else {
            return nil
        }

        guard avgLength > 0 else { return nil }
        let daysFromLastStart = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0
        let cyclesElapsed = Double(daysFromLastStart) / avgLength
        let wholeCyclesElapsed = floor(cyclesElapsed)
        let nextCycleOffset = Int(round((wholeCyclesElapsed + 1.0) * avgLength))
        return calendar.date(byAdding: .day, value: nextCycleOffset, to: lastStart)
    }

    /// Predicts next period as a date range reflecting individual cycle variability.
    func predictNextPeriodRange(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> (earliest: Date, latest: Date)? {
        guard let center = predictNextPeriod(days: days, seedData: seedData, today: today) else { return nil }
        let calendar = Calendar.current

        let periodStarts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: periodStarts)
        let halfWindow: Int

        if let sigma = cycleVariability(from: lengths) {
            halfWindow = max(2, Int(ceil(sigma)))
        } else if lengths.count == 1 {
            halfWindow = 4
        } else {
            // New user — use conservative ±5 window based on population variability
            halfWindow = 5
        }

        guard
            let earliest = calendar.date(byAdding: .day, value: -halfWindow, to: center),
            let latest = calendar.date(byAdding: .day, value: halfWindow, to: center)
        else { return nil }

        return (earliest, latest)
    }

    // MARK: - Phase & Fertility

    /// Estimated ovulation date = last period start + (avg cycle length − 14).
    func estimatedOvulationDate(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> Date? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let periodStarts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: periodStarts)
        let seedPrior = seedData.map { Double($0.typicalCycleLength) }
        let avgLength = Int(round(weightedAverageCycleLength(from: lengths, seedPrior: seedPrior)))

        let lastStart: Date
        if let logged = periodStarts.filter({ $0 <= todayStart }).last {
            lastStart = logged
        } else if let seed = seedData {
            lastStart = calendar.startOfDay(for: seed.lastPeriodStartDate)
        } else {
            return nil
        }

        let ovulationOffset = avgLength - Self.lutealPhaseLength
        return calendar.date(byAdding: .day, value: max(ovulationOffset, 1), to: lastStart)
    }

    /// Fertile window: 5 days before ovulation through ovulation day (6 days total).
    func fertileWindow(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> DateInterval? {
        guard let ovulation = estimatedOvulationDate(days: days, seedData: seedData, today: today) else { return nil }
        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -5, to: ovulation) else { return nil }
        return DateInterval(start: windowStart, end: ovulation)
    }

    /// Determines the current cycle phase based on today's position within the cycle.
    func currentPhase(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> CyclePhase? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let periodStarts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: periodStarts)
        let seedPrior = seedData.map { Double($0.typicalCycleLength) }
        let avgLength = Int(round(weightedAverageCycleLength(from: lengths, seedPrior: seedPrior)))

        let lastStart: Date
        if let logged = periodStarts.filter({ $0 <= todayStart }).last {
            lastStart = logged
        } else if let seed = seedData {
            lastStart = calendar.startOfDay(for: seed.lastPeriodStartDate)
        } else {
            return nil
        }

        let cycleDay = (calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0) + 1
        // Overdue — no meaningful phase
        guard cycleDay <= avgLength else { return nil }

        let periodLength = seedData?.typicalPeriodLength ?? 5
        let ovulationDay = avgLength - Self.lutealPhaseLength

        switch cycleDay {
        case 1...periodLength:
            return .menstrual
        case (periodLength + 1)...(ovulationDay - 2):
            return .follicular
        case (ovulationDay - 1)...(ovulationDay + 2):
            return .ovulatory
        default:
            return .luteal
        }
    }

    /// 1-indexed day number within the current cycle.
    /// Returns nil once today is past the predicted next period start — an overdue
    /// cycle has no meaningful day number and the UI should show "Late" instead.
    func currentCycleDayNumber(
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> Int? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let periodStarts = extractPeriodStarts(from: days)

        let lastStart: Date
        if let logged = periodStarts.filter({ $0 <= todayStart }).last {
            lastStart = logged
        } else if let seed = seedData {
            lastStart = calendar.startOfDay(for: seed.lastPeriodStartDate)
        } else {
            return nil
        }

        let dayNumber = (calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0) + 1
        let avgLength = averageCycleLength(from: days) ?? seedData?.typicalCycleLength ?? 28
        // Beyond the expected cycle length → overdue, return nil so UI shows "Late"
        guard dayNumber <= avgLength else { return nil }
        return dayNumber
    }

    /// Average cycle length, rounded to nearest day. Returns `nil` when fewer
    /// than 2 complete periods have been logged.
    func averageCycleLength(from days: [CycleDay]) -> Int? {
        let starts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: starts)
        guard lengths.count >= 1 else { return nil }
        let seedPrior: Double? = nil
        return Int(round(weightedAverageCycleLength(from: lengths, seedPrior: seedPrior)))
    }

    // MARK: - Multi-Cycle Forecast

    /// Returns `count` successive period forecasts starting from the next predicted period.
    ///
    /// Each successive cycle compounds uncertainty: `halfWindow` grows by 1 day per cycle
    /// beyond the first, representing the natural decay in prediction confidence.
    /// The `confidence` value (0–1) fades linearly: 1.0 for the first cycle, down to 0.25
    /// for anything 6+ cycles out.
    func forecastCycles(
        count: Int,
        days: [CycleDay],
        seedData: CycleSeedData?,
        today: Date
    ) -> [CycleForecast] {
        let calendar = Calendar.current
        let periodStarts = extractPeriodStarts(from: days)
        let lengths = cycleLengths(from: periodStarts)
        let seedPrior = seedData.map { Double($0.typicalCycleLength) }
        let avgLength = weightedAverageCycleLength(from: lengths, seedPrior: seedPrior)
        let avgLengthInt = Int(round(avgLength))

        // Base uncertainty
        let baseHalfWindow: Int
        if let sigma = cycleVariability(from: lengths) {
            baseHalfWindow = max(2, Int(ceil(sigma)))
        } else if lengths.count == 1 {
            baseHalfWindow = 4
        } else {
            baseHalfWindow = 5
        }

        // Anchor: next predicted period center
        guard let firstCenter = predictNextPeriod(days: days, seedData: seedData, today: today) else {
            return []
        }

        var results: [CycleForecast] = []
        var center = firstCenter
        let maxConfidenceCycles = 5

        for i in 0..<count {
            let halfWindow = baseHalfWindow + i  // compound: each cycle adds 1 day
            let confidence = max(0.25, 1.0 - Double(i) / Double(maxConfidenceCycles))

            guard
                let earliest = calendar.date(byAdding: .day, value: -halfWindow, to: center),
                let latest = calendar.date(byAdding: .day, value: halfWindow, to: center)
            else { break }

            // Fertile window for this forecast cycle
            let ovulationOffset = avgLengthInt - Self.lutealPhaseLength
            let fertileStart: Date?
            let fertileEnd: Date?
            if let ovulation = calendar.date(byAdding: .day, value: ovulationOffset, to: center),
               let fStart = calendar.date(byAdding: .day, value: -5, to: ovulation) {
                fertileStart = fStart
                fertileEnd = ovulation
            } else {
                fertileStart = nil
                fertileEnd = nil
            }

            results.append(CycleForecast(
                cycleIndex: i,
                periodCenter: center,
                periodEarliest: earliest,
                periodLatest: latest,
                fertileWindowStart: fertileStart,
                fertileWindowEnd: fertileEnd,
                confidence: confidence
            ))

            // Advance to next cycle center
            center = calendar.date(byAdding: .day, value: avgLengthInt, to: center) ?? center
        }

        return results
    }
}

// MARK: - CycleForecast

/// A single predicted cycle entry, used for multi-month forecast views.
struct CycleForecast {
    /// Zero-based index (0 = next period, 1 = period after that, …)
    let cycleIndex: Int
    /// Center (most likely) date for the period start.
    let periodCenter: Date
    /// Earliest plausible period start date.
    let periodEarliest: Date
    /// Latest plausible period start date.
    let periodLatest: Date
    /// Start of the fertile window for this cycle (nil if not computable).
    let fertileWindowStart: Date?
    /// End of the fertile window (ovulation day).
    let fertileWindowEnd: Date?
    /// 0–1 confidence score. 1.0 = next cycle, fades to 0.25 at 5+ cycles out.
    let confidence: Double
}
