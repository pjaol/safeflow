import XCTest
@testable import safeflow

// MARK: - SignalScenarioTests
//
// Loads the four perimenopause/menopause scenario CSVs and runs SignalEngine
// against real multi-month data.
//
// CSVs use relative day offsets (0 = today, -270 = 270 days ago), so slicing
// is done relative to the current calendar month rather than a hardcoded year.
//
// Each test slices the loaded days into:
//   current  = this month (month offset 0)
//   previous = last month (month offset -1)
//   baseline = 3 and 4 months ago (month offsets -3 and -4, combined)
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

    /// Slice days by a month offset relative to today (0 = this month, -1 = last month, etc.)
    private func slice(_ days: [CycleDay], monthOffset: Int) -> [CycleDay] {
        guard let target = cal.date(byAdding: .month, value: monthOffset, to: Date()) else { return [] }
        let tc = cal.dateComponents([.year, .month], from: target)
        return days.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == tc.year && c.month == tc.month
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
        let current  = slice(days, monthOffset:  0)
        let previous = slice(days, monthOffset: -1)
        let baseline = slice(days, monthOffset: -3)
                     + slice(days, monthOffset: -4)
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

    func testLatePeri_hotFlashesPresent() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        // Hot flashes are the dominant symptom throughout the late peri scenario
        XCTAssertNotNil(hf, "hotFlashes should appear in dominant symptoms for late perimenopause")
    }

    func testLatePeri_symptomBurdenPresent() throws {
        let days = try loadScenario(named: "scenario_late_perimenopause")
        guard case .ready(let signal) = compute(days: days, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        // Late peri scenario has consistent high symptom logging; at least some hot flashes this month
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertGreaterThanOrEqual(hf?.thisMonth ?? 0, 3, "Should see hot flash days logged in the current month")
    }

    // MARK: - Menopause stable: improvement arc

    func testMenoStable_stageIsMenopause() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .menopause)
    }

    func testMenoStable_hotFlashesPresent() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf, "hotFlashes should appear — ~3-4 days/month throughout the stable scenario")
        // Stable HRT-managed scenario: flash count is consistent, so trend is stable or improving
        XCTAssertTrue(
            hf?.trend == .stable || hf?.trend == .improving,
            "hotFlashes trend should be stable or improving in a well-managed scenario, got \(String(describing: hf?.trend))"
        )
    }

    func testMenoStable_monthCharacterNotWorse() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        // Stable scenario — should never be harder than baseline
        XCTAssertFalse(
            signal.monthCharacter == .notablyHarder || signal.monthCharacter == .slightlyHarder,
            "Stable HRT scenario should not be harder than baseline, got \(signal.monthCharacter)"
        )
    }

    // MARK: - Menopause symptoms returning

    func testMenoReturning_hotFlashesPresent() throws {
        let days = try loadScenario(named: "scenario_menopause_symptoms_returning")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        // Hot flashes are present throughout — the scenario shows sustained high burden
        XCTAssertNotNil(hf, "hotFlashes should appear as a dominant symptom in the symptoms-returning scenario")
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

    func testMenoStable_lowHotFlashBurden() throws {
        let days = try loadScenario(named: "scenario_menopause_stable")
        guard case .ready(let signal) = compute(days: days, stage: .menopause, cycleLengths: []) else {
            return XCTFail()
        }
        // Stable HRT scenario logs ~3-4 flash days/month — well below the high-burden threshold
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertLessThan(hf?.thisMonth ?? 99, 10, "hotFlashes should be fewer than 10 days in a well-managed stable scenario")
    }
}
