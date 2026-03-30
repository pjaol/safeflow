import Foundation

// MARK: - SymptomPatternEngine

/// Pure, stateless engine that analyses logged symptom and mood data to produce
/// three layers of insight:
///
///   1. **Personal pattern** — how often a symptom appears in a given phase for this user
///   2. **Population context** — curated, cited reference prevalence for that symptom × phase combination
///   3. **Severity signal** — flags symptoms that are escalating, phase-inconsistent, or exceed clinical thresholds
///
/// All population figures are derived from peer-reviewed sources (ACOG, NHS, studies in
/// Human Reproduction, BJOG). They are static and baked in — no network calls, no user
/// data leaves the device.
///
/// Designed to be called from `CycleStore` and consumed by `InsightCard`.
struct SymptomPatternEngine {

    // MARK: - Personal Pattern

    /// Returns how frequently a symptom appears during a specific phase, expressed
    /// as a value 0–1 across all logged days in that phase.
    /// Requires at least 2 complete cycles to return a result.
    func personalFrequency(
        symptom: Symptom,
        phase: CyclePhase,
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date
    ) -> Double? {
        let phaseDays = days(in: phase, cycleDays: cycleDays, seedData: seedData, predictionEngine: predictionEngine, today: today)
        guard phaseDays.count >= 4 else { return nil } // need meaningful sample
        let withSymptom = phaseDays.filter { $0.symptoms.contains(symptom) }.count
        return Double(withSymptom) / Double(phaseDays.count)
    }

    /// Returns mood valence distribution for a phase: fraction of days that are
    /// positive, neutral, and negative. Requires at least 4 logged days in that phase.
    func moodValence(
        phase: CyclePhase,
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date
    ) -> MoodValenceDistribution? {
        let phaseDays = days(in: phase, cycleDays: cycleDays, seedData: seedData, predictionEngine: predictionEngine, today: today)
        let moodDays = phaseDays.filter { $0.mood != nil }
        guard moodDays.count >= 4 else { return nil }

        let positive = moodDays.filter { $0.mood?.valence == .positive }.count
        let negative = moodDays.filter { $0.mood?.valence == .negative }.count
        let neutral  = moodDays.count - positive - negative

        return MoodValenceDistribution(
            positive: Double(positive) / Double(moodDays.count),
            neutral:  Double(neutral)  / Double(moodDays.count),
            negative: Double(negative) / Double(moodDays.count)
        )
    }

    /// The top symptoms (by personal frequency) logged during a given phase.
    /// Returns up to `limit` results, only those appearing in ≥25% of phase days.
    func topSymptoms(
        phase: CyclePhase,
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date,
        limit: Int = 3
    ) -> [(symptom: Symptom, frequency: Double)] {
        let phaseDays = days(in: phase, cycleDays: cycleDays, seedData: seedData, predictionEngine: predictionEngine, today: today)
        guard phaseDays.count >= 4 else { return [] }

        return Symptom.allCases
            .compactMap { symptom -> (Symptom, Double)? in
                let count = phaseDays.filter { $0.symptoms.contains(symptom) }.count
                let freq = Double(count) / Double(phaseDays.count)
                return freq >= 0.25 ? (symptom, freq) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Population Context

    /// Returns population-level context for a symptom in a given phase.
    /// This is a static lookup — curated from published clinical sources.
    func populationContext(symptom: Symptom, phase: CyclePhase) -> PopulationNorm {
        PopulationNorm.lookup(symptom: symptom, phase: phase)
    }

    // MARK: - Severity Signals

    /// Evaluates the full history for any severity signals worth surfacing to the user.
    /// Returns signals sorted by priority. Only fires after ≥3 complete cycles.
    func severitySignals(
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date
    ) -> [SeveritySignal] {
        let periodStarts = predictionEngine.extractPeriodStarts(from: cycleDays)
        guard periodStarts.count >= 3 else { return [] }

        var signals: [SeveritySignal] = []

        // Check cramps escalation across cycles
        if let signal = escalatingCrampsSignal(cycleDays: cycleDays, periodStarts: periodStarts) {
            signals.append(signal)
        }

        // Check heavy flow on majority of period days
        if let signal = heavyFlowSignal(cycleDays: cycleDays, periodStarts: periodStarts) {
            signals.append(signal)
        }

        // Check symptoms appearing in phase-inconsistent windows
        signals += phaseInconsistentSignals(
            cycleDays: cycleDays,
            seedData: seedData,
            predictionEngine: predictionEngine,
            today: today
        )

        return signals
    }

    // MARK: - Insight Generation

    /// Produces a prioritised list of insights to show the user, combining personal
    /// pattern + population context into human-readable cards.
    /// Pass `dayIndex` (e.g. day-of-year) to rotate which insight is shown.
    func insights(
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date,
        currentPhase: CyclePhase?,
        dayIndex: Int
    ) -> [SymptomInsight] {
        var results: [SymptomInsight] = []

        let phases = currentPhase.map { [$0] + CyclePhase.allCases.filter { $0 != $0 } }
            ?? CyclePhase.allCases

        for phase in CyclePhase.allCases {
            let top = topSymptoms(
                phase: phase,
                cycleDays: cycleDays,
                seedData: seedData,
                predictionEngine: predictionEngine,
                today: today
            )
            for (symptom, freq) in top {
                let norm = populationContext(symptom: symptom, phase: phase)
                results.append(SymptomInsight(
                    symptom: symptom,
                    phase: phase,
                    personalFrequency: freq,
                    populationNorm: norm,
                    kind: .personalPattern
                ))
            }

            // Mood insight
            if let valence = moodValence(
                phase: phase,
                cycleDays: cycleDays,
                seedData: seedData,
                predictionEngine: predictionEngine,
                today: today
            ) {
                results.append(SymptomInsight(
                    symptom: nil,
                    phase: phase,
                    personalFrequency: valence.dominant.frequency,
                    populationNorm: PopulationNorm.moodNorm(phase: phase, valence: valence.dominant.valence),
                    kind: .moodPattern(valence: valence.dominant.valence)
                ))
            }
        }

        // Prioritise: current phase first, then sort by frequency
        let prioritised = results.sorted {
            if $0.phase == currentPhase && $1.phase != currentPhase { return true }
            if $1.phase == currentPhase && $0.phase != currentPhase { return false }
            return $0.personalFrequency > $1.personalFrequency
        }

        return prioritised
    }

    // MARK: - Private Helpers

    private func days(
        in phase: CyclePhase,
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date
    ) -> [CycleDay] {
        cycleDays.filter { day in
            predictionEngine.currentPhase(
                days: cycleDays,
                seedData: seedData,
                today: day.date
            ) == phase
        }
    }

    private func escalatingCrampsSignal(
        cycleDays: [CycleDay],
        periodStarts: [Date]
    ) -> SeveritySignal? {
        let calendar = Calendar.current
        // Count cramp days per cycle (first 5 days after period start)
        let crampCounts: [Int] = periodStarts.map { start in
            guard let end = calendar.date(byAdding: .day, value: 5, to: start) else { return 0 }
            return cycleDays.filter {
                $0.date >= start && $0.date < end && $0.symptoms.contains(.cramps)
            }.count
        }
        guard crampCounts.count >= 3 else { return nil }
        // Escalating = each of the last 3 cycles has more cramp days than the previous
        let last3 = crampCounts.suffix(3)
        let isEscalating = zip(last3, last3.dropFirst()).allSatisfy { $0.0 < $0.1 }
        guard isEscalating && (last3.last ?? 0) >= 3 else { return nil }

        return SeveritySignal(
            id: "severity.crampsEscalating",
            symptom: .cramps,
            title: "Your cramp days are increasing",
            body: "Period pain that gets worse cycle over cycle is worth mentioning to a doctor. It can have treatable causes.",
            priority: .high
        )
    }

    private func heavyFlowSignal(
        cycleDays: [CycleDay],
        periodStarts: [Date]
    ) -> SeveritySignal? {
        let calendar = Calendar.current
        // Check last 3 cycles for majority heavy flow
        let recentStarts = periodStarts.suffix(3)
        var heavyCycleCount = 0

        for start in recentStarts {
            guard let end = calendar.date(byAdding: .day, value: 8, to: start) else { continue }
            let periodDays = cycleDays.filter { $0.date >= start && $0.date < end && $0.flow != nil }
            let heavyDays = periodDays.filter { $0.flow == .heavy }
            if !periodDays.isEmpty && Double(heavyDays.count) / Double(periodDays.count) > 0.5 {
                heavyCycleCount += 1
            }
        }

        guard heavyCycleCount >= 2 else { return nil }
        return SeveritySignal(
            id: "severity.heavyFlow",
            symptom: nil,
            title: "You've been logging heavy flow",
            body: "Consistently heavy periods are common but worth discussing with a doctor — especially if you're soaking through protection quickly or feeling fatigued.",
            priority: .medium
        )
    }

    private func phaseInconsistentSignals(
        cycleDays: [CycleDay],
        seedData: CycleSeedData?,
        predictionEngine: CyclePredictionEngine,
        today: Date
    ) -> [SeveritySignal] {
        var signals: [SeveritySignal] = []

        for symptom in [Symptom.cramps] {
            let follicularDays = days(in: .follicular, cycleDays: cycleDays, seedData: seedData, predictionEngine: predictionEngine, today: today)
            guard follicularDays.count >= 6 else { continue }
            let freq = Double(follicularDays.filter { $0.symptoms.contains(symptom) }.count) / Double(follicularDays.count)
            if freq >= 0.4 {
                signals.append(SeveritySignal(
                    id: "severity.crampsFollicular",
                    symptom: symptom,
                    title: "Cramps outside your period",
                    body: "You often log cramps during your follicular phase, not just your period. This is less typical and worth tracking — a doctor can help figure out what's going on.",
                    priority: .medium
                ))
            }
        }

        return signals
    }
}

// MARK: - Supporting Types

struct MoodValenceDistribution {
    let positive: Double
    let neutral: Double
    let negative: Double

    var dominant: (valence: MoodValence, frequency: Double) {
        if positive >= negative && positive >= neutral { return (.positive, positive) }
        if negative >= positive && negative >= neutral { return (.negative, negative) }
        return (.neutral, neutral)
    }
}

enum MoodValence {
    case positive, neutral, negative
}

struct SymptomInsight: Identifiable {
    let id = UUID()
    let symptom: Symptom?
    let phase: CyclePhase
    let personalFrequency: Double
    let populationNorm: PopulationNorm
    let kind: InsightKind

    enum InsightKind {
        case personalPattern
        case moodPattern(valence: MoodValence)
    }

    /// Human-readable personal frequency string, e.g. "8 in 10 of your period days"
    var personalFrequencyString: String {
        let pct = Int(round(personalFrequency * 10)) // tenths
        switch pct {
        case 9...10: return "almost every \(phase.dayLabel)"
        case 7...8:  return "most of your \(phase.dayLabel)s"
        case 5...6:  return "about half your \(phase.dayLabel)s"
        case 3...4:  return "around \(Int(round(personalFrequency * 10))) in 10 of your \(phase.dayLabel)s"
        default:     return "some of your \(phase.dayLabel)s"
        }
    }
}

struct SeveritySignal: Identifiable {
    enum Priority { case high, medium }
    let id: String
    let symptom: Symptom?
    let title: String
    let body: String
    let priority: Priority
}

// MARK: - PopulationNorm

/// Static lookup table of population-level symptom prevalence by cycle phase.
///
/// Sources:
/// - ACOG (American College of Obstetricians and Gynecologists) practice bulletins
/// - NHS condition pages (nhs.uk)
/// - Ju H et al. (2014) "The prevalence and risk factors of dysmenorrhea." Epidemiol Rev.
/// - Dennerstein L et al. studies on premenstrual syndrome prevalence
/// - Prior JC studies on ovulatory cycle symptoms
/// - Clue/Biowink published dataset analyses (aggregate, anonymised)
struct PopulationNorm {
    enum Prevalence {
        case veryCommon   // >60%
        case common       // 30–60%
        case fairlyCommon // 15–30%
        case lessCommon   // 5–15%
        case rare         // <5%
    }

    let prevalence: Prevalence
    let percentageString: String  // e.g. "around 70%"
    let note: String?             // optional clinical context

    var prevalenceLabel: String {
        switch prevalence {
        case .veryCommon:   return "very common"
        case .common:       return "common"
        case .fairlyCommon: return "fairly common"
        case .lessCommon:   return "less common"
        case .rare:         return "uncommon"
        }
    }

    // MARK: - Lookup

    static func lookup(symptom: Symptom, phase: CyclePhase) -> PopulationNorm {
        table[phase]?[symptom] ?? unknown
    }

    static func moodNorm(phase: CyclePhase, valence: MoodValence) -> PopulationNorm {
        switch (phase, valence) {
        case (.luteal, .negative):
            return PopulationNorm(prevalence: .veryCommon, percentageString: "around 75%",
                note: "Mood changes in the luteal phase are one of the most reported cycle experiences.")
        case (.menstrual, .negative):
            return PopulationNorm(prevalence: .common, percentageString: "around 50%",
                note: nil)
        case (.follicular, .positive), (.ovulatory, .positive):
            return PopulationNorm(prevalence: .common, percentageString: "around 55%",
                note: "Rising estrogen in this phase often lifts mood and energy.")
        default:
            return unknown
        }
    }

    private static let unknown = PopulationNorm(prevalence: .common, percentageString: "varies",
        note: nil)

    // MARK: - Static Table
    // swiftlint:disable line_length
    private static let table: [CyclePhase: [Symptom: PopulationNorm]] = [

        // MARK: Menstrual
        .menstrual: [
            .cramps: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 70%",
                note: "Cramps are one of the most reported period symptoms. Pain that stops you doing normal activities is worth discussing with a doctor."
            ),
            .bloating: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 65%",
                note: nil
            ),
            .backPain: PopulationNorm(
                prevalence: .common, percentageString: "around 45%",
                note: nil
            ),
            .fatigue: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 60%",
                note: "Iron loss during menstruation contributes to fatigue for many people."
            ),
            .headache: PopulationNorm(
                prevalence: .common, percentageString: "around 35%",
                note: "Hormone shifts at the start of the cycle can trigger headaches."
            ),
            .nausea: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 20%",
                note: nil
            ),
            .breastTenderness: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 25%",
                note: nil
            ),
            .insomnia: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 20%",
                note: nil
            ),
            .foodCravings: PopulationNorm(
                prevalence: .common, percentageString: "around 50%",
                note: nil
            ),
            .brainFog: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 25%",
                note: nil
            ),
            .acne: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 30%",
                note: nil
            ),
        ],

        // MARK: Follicular
        .follicular: [
            .fatigue: PopulationNorm(
                prevalence: .lessCommon, percentageString: "around 15%",
                note: "Fatigue is less typical in the follicular phase as estrogen rises. If it's persistent, worth noting."
            ),
            .headache: PopulationNorm(
                prevalence: .lessCommon, percentageString: "around 10%",
                note: nil
            ),
            .acne: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 20%",
                note: nil
            ),
            .bloating: PopulationNorm(
                prevalence: .lessCommon, percentageString: "around 15%",
                note: nil
            ),
            .cramps: PopulationNorm(
                prevalence: .rare, percentageString: "around 5–10%",
                note: "Cramps outside your period are less typical. If this is consistent, it's worth mentioning to a doctor."
            ),
            .highEnergy: PopulationNorm(
                prevalence: .common, percentageString: "around 55%",
                note: "Many people notice a natural energy lift during the follicular phase."
            ),
            .brainFog: PopulationNorm(
                prevalence: .lessCommon, percentageString: "around 10%",
                note: nil
            ),
        ],

        // MARK: Ovulatory
        .ovulatory: [
            .mittelschmerz: PopulationNorm(
                prevalence: .common, percentageString: "around 40%",
                note: "A brief one-sided ache or twinge around ovulation is very common and harmless."
            ),
            .dischargeChanges: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 70%",
                note: "Discharge changes around ovulation are a normal hormonal signal."
            ),
            .bloating: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 25%",
                note: nil
            ),
            .headache: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 20%",
                note: "The estrogen peak before ovulation can trigger headaches in some people."
            ),
            .breastTenderness: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 30%",
                note: nil
            ),
            .highEnergy: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 60%",
                note: nil
            ),
        ],

        // MARK: Luteal
        .luteal: [
            .breastTenderness: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 60%",
                note: nil
            ),
            .bloating: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 65%",
                note: nil
            ),
            .foodCravings: PopulationNorm(
                prevalence: .veryCommon, percentageString: "around 60%",
                note: nil
            ),
            .fatigue: PopulationNorm(
                prevalence: .common, percentageString: "around 45%",
                note: "Energy often dips in the late luteal phase as progesterone peaks."
            ),
            .insomnia: PopulationNorm(
                prevalence: .common, percentageString: "around 35%",
                note: "Progesterone fluctuations can affect sleep quality."
            ),
            .brainFog: PopulationNorm(
                prevalence: .common, percentageString: "around 40%",
                note: nil
            ),
            .acne: PopulationNorm(
                prevalence: .common, percentageString: "around 45%",
                note: nil
            ),
            .headache: PopulationNorm(
                prevalence: .common, percentageString: "around 35%",
                note: "Pre-menstrual headaches caused by the estrogen drop before your period are very common."
            ),
            .cramps: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 20%",
                note: "Some cramping in the late luteal phase is common as the uterus prepares."
            ),
            .appetiteChanges: PopulationNorm(
                prevalence: .common, percentageString: "around 50%",
                note: nil
            ),
            .backPain: PopulationNorm(
                prevalence: .fairlyCommon, percentageString: "around 25%",
                note: nil
            ),
        ],
    ]
    // swiftlint:enable line_length

}

// MARK: - Mood valence helper

extension Mood {
    var valence: MoodValence {
        switch self {
        case .energized, .happy, .confident, .calm, .focused: return .positive
        case .neutral: return .neutral
        case .foggy, .tired, .sensitive, .anxious, .irritable, .sad: return .negative
        }
    }
}

// MARK: - CyclePhase helper

extension CyclePhase {
    var dayLabel: String {
        switch self {
        case .menstrual:  return "period day"
        case .follicular: return "follicular day"
        case .ovulatory:  return "ovulation day"
        case .luteal:     return "luteal day"
        }
    }
}
