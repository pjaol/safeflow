import XCTest
@testable import safeflow

// MARK: - SignalScenarioTests
//
// Loads the four perimenopause/menopause scenario CSVs and runs SignalEngine
// against real multi-month data. Reference "today" = 2025-04-30.
//
// Each test slices the loaded days into:
//   current  = April 2025
//   previous = March 2025
//   baseline = January + February 2025 (combined)
//
// Cycle lengths are derived from flow start dates in the CSV.

final class SignalScenarioTests: XCTestCase {

    // MARK: - Helpers

    private let loader = TestDataLoader()
    private let cal    = Calendar.current

    private func loadScenario(named filename: String) throws -> [CycleDay] {
        guard let url = Bundle(for: type(of: self)).url(forResource: filename, withExtension: "csv") else {
            throw XCTSkip("CSV not in test bundle: \(filename).csv — add to target resources")
        }
        let csv = try String(contentsOf: url, encoding: .utf8)
        let entries = try loader.parseEntriesPublic(from: csv)
        return entries.map { entry in
            CycleDay(
                date: entry.date,
                flow: entry.flow,
                symptoms: entry.symptoms,
                mood: entry.mood,
                notes: entry.notes
            )
        }
    }

    private func slice(_ days: [CycleDay], year: Int, month: Int) -> [CycleDay] {
        days.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }
    }

    /// Extracts cycle start dates (first flow day after a gap) and returns lengths.
    private func cycleLengths(from days: [CycleDay]) -> [Int] {
        let flowDays = days
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }

        var starts: [Date] = []
        var lastFlow: Date? = nil
        for day in flowDays {
            if let last = lastFlow {
                let gap = cal.dateComponents([.day], from: last, to: day.date).day ?? 0
                if gap > 5 { starts.append(day.date) }
            } else {
                starts.append(day.date)
            }
            lastFlow = day.date
        }

        guard starts.count >= 2 else { return [] }
        return zip(starts, starts.dropFirst()).map { s, e in
            cal.dateComponents([.day], from: s, to: e).day ?? 0
        }
    }

    private func compute(
        days: [CycleDay],
        stage: LifeStage,
        cycleLengths: [Int]
    ) -> SignalReadiness {
        let current  = slice(days, year: 2025, month: 4)
        let previous = slice(days, year: 2025, month: 3)
        let baseline = slice(days, year: 2025, month: 1)
                     + slice(days, year: 2025, month: 2)
        return SignalEngine.compute(
            current: current,
            previous: previous,
            baseline: baseline,
            stage: stage,
            cycleLengths: cycleLengths
        )
    }

    // MARK: - Early perimenopause: escalating hot flashes

    func testEarlyPeri_isReady() throws {
        let days = try loadScenario(named: "scenario_early_perimenopause")
        let result = compute(days: days, stage: .perimenopause, cycleLengths: [28, 30, 31, 42])
        guard case .ready = result else {
            return XCTFail("Expected .ready — April has 17+ logged days")
        }
    }

    func testEarlyPeri_stageIsEarly() throws {
        let days = try loadScenario(named: "scenario_early_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: [28, 30, 31, 42]) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .earlyPerimenopause)
    }

    func testEarlyPeri_hotFlashesEscalating() throws {
        let days = try loadScenario(named: "scenario_early_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: [28, 30, 31, 42]) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf, "hotFlashes should appear in dominant symptoms")
        XCTAssertEqual(hf?.trend, .escalating, "hotFlashes should be escalating — absent in Jan, growing through Apr")
    }

    func testEarlyPeri_monthIsHarder() throws {
        let days = try loadScenario(named: "scenario_early_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: [28, 30, 31, 42]) else {
            return XCTFail()
        }
        XCTAssertTrue(
            signal.monthCharacter == .notablyHarder || signal.monthCharacter == .slightlyHarder,
            "April symptom burden should be heavier than Jan/Feb baseline, got \(signal.monthCharacter)"
        )
    }

    // MARK: - Late perimenopause: heavy sustained burden

    func testLatePeri_stageIsLate() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        // No flow at all → cycleLengths empty → inferred as late
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .latePerimenopause)
    }

    func testLatePeri_hotFlashesEscalatingOrStable() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf)
        // Jan/Feb already high, Apr still high — could be stable or escalating
        XCTAssertTrue(
            hf?.trend == .escalating || hf?.trend == .stable,
            "hotFlashes should be escalating or stable at high burden, got \(String(describing: hf?.trend))"
        )
    }

    func testLatePeri_highSymptomBurden() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertGreaterThanOrEqual(hf?.thisMonth ?? 0, 15, "Should see 15+ hot flash days in April")
    }

    // MARK: - Menopause stable: improvement arc

    func testMenoStable_stageIsMenopause() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .menopause)
    }

    func testMenoStable_hotFlashesImproving() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf)
        XCTAssertEqual(hf?.trend, .improving, "hotFlashes should improve — 16 days in Jan down to ~8 in Apr")
    }

    func testMenoStable_monthCharacterImproving() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertTrue(
            signal.monthCharacter == .notableImprovement || signal.monthCharacter == .slightImprovement,
            "April should be better than Jan/Feb baseline, got \(signal.monthCharacter)"
        )
    }

    // MARK: - Menopause symptoms returning

    func testMenoReturning_hotFlashesEscalating() throws {
        let days = try loadScenario(named: "scenario_menopause_symptoms_returning")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf)
        XCTAssertEqual(hf?.trend, .escalating, "hotFlashes escalating — 4-5 days in Jan/Feb, 16 days in Apr")
    }

    func testMenoReturning_monthNotablyHarder() throws {
        let days = try loadScenario(named: "scenario_menopause_symptoms_returning")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertTrue(
            signal.monthCharacter == .notablyHarder || signal.monthCharacter == .slightlyHarder,
            "April is much worse than quiet Jan/Feb baseline, got \(signal.monthCharacter)"
        )
    }

    func testMenoReturning_hasBaseline() throws {
        let days = try loadScenario(named: "scenario_menopause_symptoms_returning")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertTrue(signal.hasBaseline)
    }

    // MARK: - Cross-scenario: correct dominant symptom

    func testLatePeri_dominantIsHotFlashesOrNightSweats() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        let top = signal.dominantSymptoms.first?.symptom
        XCTAssertTrue(
            top == .hotFlashes || top == .nightSweats,
            "Top symptom should be vasomotor, got \(String(describing: top))"
        )
    }

    func testMenoStable_fewerDominantSymptomsInApril() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        // April has many symptom-free days — top symptom count should be < Jan count
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertLessThan(hf?.thisMonth ?? 99, 10, "hotFlashes should be fewer than 10 days in April")
    }
}
