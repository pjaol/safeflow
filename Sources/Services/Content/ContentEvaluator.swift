import Foundation

/// Evaluates content trigger rules against current CycleStore state.
///
/// Replaces scattered hardcoded logic in PhaseTipCard, PatternNudgeCard,
/// and CycleNudge.evaluate(). All trigger evaluation lives here.
///
/// Usage:
///   let evaluator = ContentEvaluator(store: cycleStore)
///   let tip   = evaluator.dailyTip()
///   let nudge = evaluator.activeNudge(dismissed: dismissedIDs)
///   let sigs  = evaluator.activeSignals(dismissed: dismissedIDs)
@MainActor
struct ContentEvaluator {

    private let store: CycleStore
    private let calendar = Calendar.current

    // Derived state — computed once per evaluator instance
    private let completedCycles: Int
    private let avgCycleLength: Int?
    private let cycleVariability: Double?
    private let loggedSymptoms: Set<String>   // symptom rawValues seen in last 2 cycles
    private let currentPhase: CyclePhase?
    private let periodStarts: [Date]
    private let engine: CyclePredictionEngine

    init(store: CycleStore) {
        self.store = store
        self.engine = CyclePredictionEngine()

        let days = store.getAllDays()
        self.periodStarts    = engine.extractPeriodStarts(from: days)
        self.completedCycles = max(0, periodStarts.count - 1)
        self.currentPhase    = store.currentPhase()

        let lengths = engine.cycleLengths(from: periodStarts)
        self.avgCycleLength   = lengths.isEmpty ? nil : lengths.reduce(0, +) / lengths.count
        self.cycleVariability = engine.cycleVariability(from: lengths)

        // Symptoms logged in the last ~60 days (approx 2 cycles)
        let cutoff = calendar.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        self.loggedSymptoms = Set(
            days.filter { $0.date >= cutoff }
                .flatMap { $0.symptoms.map { $0.rawValue } }
        )
    }

    // MARK: - Tips

    /// Returns the tip to show today, rotating daily within eligible tips for the current phase.
    /// Falls back to any-phase tips if no phase-specific tips are eligible.
    func dailyTip() -> ContentTip? {
        let eligible = ContentLoader.tips.filter { isEligible($0) }
        guard !eligible.isEmpty else { return nil }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return eligible[dayOfYear % eligible.count]
    }

    // MARK: - Nudges

    /// Returns the highest-priority undismissed nudge whose trigger conditions are met.
    func activeNudge(dismissed: Set<String>) -> ContentNudge? {
        ContentLoader.nudges
            .filter { !dismissed.contains($0.id) && isTriggered($0) }
            .sorted { priorityRank($0.priority) > priorityRank($1.priority) }
            .first
    }

    // MARK: - Signals

    /// Returns all active undismissed severity signals.
    func activeSignals(dismissed: Set<String>) -> [ContentSignal] {
        ContentLoader.signals
            .filter { !dismissed.contains($0.id) && isSignalTriggered($0) }
            .sorted { priorityRank($0.priority) > priorityRank($1.priority) }
    }

    // MARK: - Resources

    /// Returns resources relevant to a set of tag keywords, sorted by region match.
    func resources(for tags: [String], region: String? = nil) -> [ContentResource] {
        let tagSet = Set(tags)
        return ContentLoader.resources
            .filter { !Set($0.tags).isDisjoint(with: tagSet) }
            .sorted { a, b in
                // Prefer exact region match, then global, then others
                let aScore = regionScore(a.region, preferred: region)
                let bScore = regionScore(b.region, preferred: region)
                return aScore > bScore
            }
    }

    // MARK: - Tip eligibility

    private func isEligible(_ tip: ContentTip) -> Bool {
        // Phase filter
        if tip.phase != "any" {
            guard let phase = currentPhase,
                  phase.rawValue == tip.phase else { return false }
        }

        // Minimum cycle count
        if let min = tip.cycleCountMin, completedCycles < min { return false }

        // Symptom filters — optional, improve relevance when present
        if !tip.symptomsAny.isEmpty {
            guard !tip.symptomsAny.allSatisfy({ !loggedSymptoms.contains($0) }) else { return false }
        }
        if !tip.symptomsAll.isEmpty {
            guard tip.symptomsAll.allSatisfy({ loggedSymptoms.contains($0) }) else { return false }
        }

        return true
    }

    // MARK: - Nudge trigger evaluation

    private func isTriggered(_ nudge: ContentNudge) -> Bool {
        guard let min = nudge.cycleCountMin else { return false }
        guard completedCycles >= min else { return false }

        // Health pattern triggers
        if let max = nudge.avgCycleMax, let avg = avgCycleLength {
            guard avg < max else { return false }
        }
        if let minLen = nudge.avgCycleMin, let avg = avgCycleLength {
            guard avg > minLen else { return false }
        }
        if let varMin = nudge.variabilityMin, let v = cycleVariability {
            guard v > varMin else { return false }
        }
        if let periodMin = nudge.periodLengthMin {
            guard hasLongPeriods(minDays: periodMin) else { return false }
        }

        // Comfort triggers — symptom-based
        if !nudge.symptomsAny.isEmpty {
            guard nudge.symptomsAny.contains(where: { loggedSymptoms.contains($0) }) else { return false }
        }
        if !nudge.symptomsAll.isEmpty {
            guard nudge.symptomsAll.allSatisfy({ loggedSymptoms.contains($0) }) else { return false }
        }

        return true
    }

    // MARK: - Signal trigger evaluation

    private func isSignalTriggered(_ signal: ContentSignal) -> Bool {
        guard let min = signal.cycleCountMin, completedCycles >= min else { return false }

        switch signal.checkType {
        case "cramps_escalating":
            return crampsAreEscalating()
        case "heavy_flow_majority":
            return hasHeavyFlowMajority()
        case "cramps_follicular":
            return hasCrampsInFollicular()
        case "severe_cluster":
            return hasSevereSymptomCluster()
        default:
            return false
        }
    }

    // MARK: - Named signal checks (mirrors existing SymptomPatternEngine logic)

    private func crampsAreEscalating() -> Bool {
        let days = store.getAllDays()
        let recentStarts = periodStarts.suffix(3)
        guard recentStarts.count >= 3 else { return false }

        var crampCounts: [Int] = []
        for (i, start) in recentStarts.enumerated() {
            let end = i + 1 < recentStarts.count
                ? recentStarts[recentStarts.index(recentStarts.startIndex, offsetBy: i + 1)]
                : calendar.date(byAdding: .day, value: 10, to: start)!
            let count = days.filter { $0.date >= start && $0.date < end && $0.symptoms.contains(.cramps) }.count
            crampCounts.append(count)
        }
        return crampCounts == crampCounts.sorted() && crampCounts.last ?? 0 >= 3
    }

    private func hasHeavyFlowMajority() -> Bool {
        let days = store.getAllDays()
        let recentStarts = periodStarts.suffix(3)
        guard recentStarts.count >= 2 else { return false }

        var heavyCount = 0
        for (i, start) in recentStarts.enumerated() {
            let end = i + 1 < recentStarts.count
                ? recentStarts[recentStarts.index(recentStarts.startIndex, offsetBy: i + 1)]
                : calendar.date(byAdding: .day, value: 10, to: start)!
            let periodDays = days.filter { $0.date >= start && $0.date < end && $0.flow != nil }
            let heavyDays  = periodDays.filter { $0.flow == .heavy }
            if !periodDays.isEmpty && Double(heavyDays.count) / Double(periodDays.count) > 0.5 {
                heavyCount += 1
            }
        }
        return heavyCount >= 2
    }

    private func hasCrampsInFollicular() -> Bool {
        guard let phase = currentPhase else { return false }
        _ = phase  // suppress warning — phase awareness used implicitly via date range
        let days = store.getAllDays()
        // Approximate follicular days as days 6–13 of each cycle
        var follicularDays: [CycleDay] = []
        for (i, start) in periodStarts.enumerated() {
            let cycleEnd = i + 1 < periodStarts.count ? periodStarts[i + 1] : Date()
            _ = cycleEnd
            guard let fStart = calendar.date(byAdding: .day, value: 5, to: start),
                  let fEnd   = calendar.date(byAdding: .day, value: 14, to: start) else { continue }
            follicularDays += days.filter { $0.date >= fStart && $0.date < fEnd }
        }
        guard follicularDays.count >= 6 else { return false }
        let cramped = follicularDays.filter { $0.symptoms.contains(.cramps) }
        return Double(cramped.count) / Double(follicularDays.count) >= 0.4
    }

    private func hasSevereSymptomCluster() -> Bool {
        let severeSym: Set<Symptom> = [.cramps, .headache, .bloating, .fatigue, .backPain]
        let days = store.getAllDays()
        let recentStarts = periodStarts.suffix(3)
        guard recentStarts.count >= 3 else { return false }

        var severeCount = 0
        for (i, start) in recentStarts.enumerated() {
            let end = i + 1 < recentStarts.count
                ? recentStarts[recentStarts.index(recentStarts.startIndex, offsetBy: i + 1)]
                : calendar.date(byAdding: .day, value: 10, to: start)!
            let periodSymptoms = days
                .filter { $0.date >= start && $0.date < end }
                .reduce(Set<Symptom>()) { $0.union($1.symptoms) }
            if periodSymptoms.intersection(severeSym).count >= 3 { severeCount += 1 }
        }
        return severeCount >= 3
    }

    private func hasLongPeriods(minDays: Int) -> Bool {
        let days = store.getAllDays()
        let recentStarts = periodStarts.suffix(3)
        guard recentStarts.count >= 2 else { return false }
        let flowDays = days.filter { $0.flow != nil && $0.flow != .spotting }
        var longCount = 0
        for (i, start) in recentStarts.enumerated() {
            let end = i + 1 < recentStarts.count
                ? recentStarts[recentStarts.index(recentStarts.startIndex, offsetBy: i + 1)]
                : calendar.date(byAdding: .day, value: 10, to: start)!
            if flowDays.filter({ $0.date >= start && $0.date < end }).count > minDays { longCount += 1 }
        }
        return longCount >= 2
    }

    // MARK: - Helpers

    private func priorityRank(_ p: String) -> Int {
        switch p { case "high": return 3; case "medium": return 2; default: return 1 }
    }

    private func regionScore(_ region: String, preferred: String?) -> Int {
        guard let preferred else { return region == "global" ? 1 : 0 }
        if region == preferred { return 2 }
        if region == "global"  { return 1 }
        return 0
    }
}
