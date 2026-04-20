import XCTest
@testable import safeflow

// MARK: - SignalEngineTests
//
// All fixtures are inline — synthetic [CycleDay] arrays, no CycleStore, no UserDefaults.
// Reference date: 2025-04-15 (mid-month, arbitrary).

final class SignalEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: string)!
    }

    /// Build a CycleDay with arbitrary date offset from a base date string.
    private func day(
        _ dateString: String,
        symptoms: Set<Symptom> = [],
        mood: Mood? = nil,
        flow: FlowIntensity? = nil
    ) -> CycleDay {
        CycleDay(
            date: makeDate(dateString),
            flow: flow,
            symptoms: symptoms,
            mood: mood
        )
    }

    /// Build N days of a given month string (e.g. "2025-04") each with the same symptom set.
    private func days(
        month: String,
        count: Int,
        symptoms: Set<Symptom> = []
    ) -> [CycleDay] {
        (1...count).map { n in
            let dateString = String(format: "%@-%02d", month, n)
            return day(dateString, symptoms: symptoms)
        }
    }

    private func compute(
        current:      [CycleDay],
        previous:     [CycleDay] = [],
        baseline:     [CycleDay] = [],
        stage:        LifeStage = .perimenopause,
        cycleLengths: [Int] = [28, 32, 35]
    ) -> SignalReadiness {
        SignalEngine.compute(
            current: current,
            previous: previous,
            baseline: baseline,
            stage: stage,
            cycleLengths: cycleLengths
        )
    }

    // MARK: - Learning state

    func testLearning_zeroDays() {
        let result = compute(current: [])
        guard case .learning(let count) = result else {
            return XCTFail("Expected .learning, got \(result)")
        }
        XCTAssertEqual(count, 0)
    }

    func testLearning_sixDays() {
        let current = days(month: "2025-04", count: 6, symptoms: [.hotFlashes])
        let result = compute(current: current)
        guard case .learning(let count) = result else {
            return XCTFail("Expected .learning, got \(result)")
        }
        XCTAssertEqual(count, 6)
    }

    func testReady_sevenDays() {
        let current = days(month: "2025-04", count: 7, symptoms: [.hotFlashes])
        let result = compute(current: current)
        guard case .ready = result else {
            return XCTFail("Expected .ready at exactly 7 days, got \(result)")
        }
    }

    // MARK: - Stage resolution

    func testStage_perimenopause_shortCycles_isEarly() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .perimenopause, cycleLengths: [28, 32, 35]) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .earlyPerimenopause)
    }

    func testStage_perimenopause_longLastGap_isLate() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .perimenopause, cycleLengths: [28, 32, 65]) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .latePerimenopause)
    }

    func testStage_perimenopause_fewerThanTwoCycleLengths_isLate() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .perimenopause, cycleLengths: [28]) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .latePerimenopause)
    }

    func testStage_perimenopause_noCycleLengths_isLate() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .perimenopause, cycleLengths: []) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .latePerimenopause)
    }

    func testStage_menopause() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .menopause) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .menopause)
    }

    func testStage_paused() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current, stage: .paused) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.stage, .paused)
    }

    // MARK: - No baseline

    func testNoBaseline_hasBaselineFalse() {
        let current = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        guard case .ready(let signal) = compute(current: current, previous: [], baseline: []) else {
            return XCTFail()
        }
        XCTAssertFalse(signal.hasBaseline)
    }

    func testNoBaseline_monthCharacterIsNoComparison() {
        let current = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.monthCharacter, .noComparison)
    }

    func testNoBaseline_symptomTrendIsUnknown() {
        let current = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        XCTAssertTrue(signal.dominantSymptoms.allSatisfy { $0.trend == .unknown })
    }

    // MARK: - Symptom trend: escalating

    func testSymptomTrend_escalating() {
        // Baseline: hotFlashes 4 days per month (8 across 2 months) → avg 4
        // Previous: 5 days
        // Current:  9 days — delta = +5, and current > previous → escalating
        let current  = days(month: "2025-04", count: 9,  symptoms: [.hotFlashes])
        let previous = days(month: "2025-03", count: 5,  symptoms: [.hotFlashes])
        let baseline = days(month: "2025-02", count: 4,  symptoms: [.hotFlashes])
                     + days(month: "2025-01", count: 4,  symptoms: [.hotFlashes])

        guard case .ready(let signal) = compute(current: current, previous: previous, baseline: baseline) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertNotNil(hf)
        XCTAssertEqual(hf?.trend, .escalating)
        XCTAssertEqual(hf?.thisMonth, 9)
        XCTAssertEqual(hf?.baselineAvg, 4.0)
    }

    // MARK: - Symptom trend: improving

    func testSymptomTrend_improving() {
        // Baseline avg: 14 days/month → current 7 days → delta -7 → improving
        let current  = days(month: "2025-04", count: 7,  symptoms: [.hotFlashes])
        let previous = days(month: "2025-03", count: 10, symptoms: [.hotFlashes])
        let baseline = days(month: "2025-02", count: 14, symptoms: [.hotFlashes])
                     + days(month: "2025-01", count: 14, symptoms: [.hotFlashes])

        guard case .ready(let signal) = compute(current: current, previous: previous, baseline: baseline) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertEqual(hf?.trend, .improving)
    }

    // MARK: - Symptom trend: stable

    func testSymptomTrend_stable() {
        // Baseline avg: 7/month → current 8 → delta +1, within ±3
        let current  = days(month: "2025-04", count: 8, symptoms: [.hotFlashes])
        let previous = days(month: "2025-03", count: 7, symptoms: [.hotFlashes])
        let baseline = days(month: "2025-02", count: 7, symptoms: [.hotFlashes])
                     + days(month: "2025-01", count: 7, symptoms: [.hotFlashes])

        guard case .ready(let signal) = compute(current: current, previous: previous, baseline: baseline) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertEqual(hf?.trend, .stable)
    }

    // MARK: - Symptom trend: new

    func testSymptomTrend_new() {
        // hotFlashes absent in baseline, appears this month
        let current  = days(month: "2025-04", count: 8, symptoms: [.hotFlashes])
        let previous = days(month: "2025-03", count: 7)
        let baseline = days(month: "2025-02", count: 7)
                     + days(month: "2025-01", count: 7)

        guard case .ready(let signal) = compute(current: current, previous: previous, baseline: baseline) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertEqual(hf?.trend, .new)
    }

    // MARK: - Symptom trend: resolved

    func testSymptomTrend_resolved() {
        // hotFlashes in baseline (avg 6/month), absent this month
        let current  = days(month: "2025-04", count: 10)   // no symptoms
        let previous = days(month: "2025-03", count: 8)
        let baseline = days(month: "2025-02", count: 6, symptoms: [.hotFlashes])
                     + days(month: "2025-01", count: 6, symptoms: [.hotFlashes])

        guard case .ready(let signal) = compute(current: current, previous: previous, baseline: baseline) else {
            return XCTFail()
        }
        let hf = signal.dominantSymptoms.first { $0.symptom == .hotFlashes }
        XCTAssertEqual(hf?.trend, .resolved)
        XCTAssertEqual(hf?.thisMonth, 0)
    }

    // MARK: - Dominant symptom ranking

    func testDominantSymptoms_rankedByFrequency() {
        // nightSweats 12 days, hotFlashes 7, jointPain 3
        var currentDays: [CycleDay] = []
        currentDays += days(month: "2025-04", count: 12).map { d in
            CycleDay(date: d.date, symptoms: [.nightSweats])
        }
        // Override first 7 to also have hotFlashes by rebuilding
        let current: [CycleDay] = (1...15).map { n in
            let date = makeDate(String(format: "2025-04-%02d", n))
            var s: Set<Symptom> = []
            if n <= 12 { s.insert(.nightSweats) }
            if n <= 7  { s.insert(.hotFlashes) }
            if n <= 3  { s.insert(.jointPain) }
            return CycleDay(date: date, symptoms: s)
        }

        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.dominantSymptoms.first?.symptom, .nightSweats)
        XCTAssertEqual(signal.dominantSymptoms.dropFirst().first?.symptom, .hotFlashes)
    }

    func testDominantSymptoms_maxThreeActive() {
        // 5 different symptoms present
        let current = (1...10).map { n -> CycleDay in
            let date = makeDate(String(format: "2025-04-%02d", n))
            return CycleDay(date: date, symptoms: [.hotFlashes, .nightSweats, .jointPain, .fatigue, .brainFog])
        }
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        let activeCount = signal.dominantSymptoms.filter { $0.trend != .resolved }.count
        XCTAssertLessThanOrEqual(activeCount, 3)
    }

    // MARK: - Month character

    func testMonthCharacter_notableImprovement() {
        // Baseline avg: 14 symptom days/month → current 6 → ratio 0.43
        let current  = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
            + days(month: "2025-04", count: 6).map { CycleDay(date: $0.date, symptoms: []) }
        // 6 days with symptoms out of 16 logged
        let sixWithSymptoms = (1...6).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-04-%02d", n)), symptoms: [.hotFlashes])
        }
        let tenWithout = (7...16).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-04-%02d", n)), symptoms: [])
        }
        let baseline = (1...14).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-02-%02d", n)), symptoms: [.hotFlashes])
        } + (1...14).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-01-%02d", n)), symptoms: [.hotFlashes])
        }

        guard case .ready(let signal) = compute(
            current: sixWithSymptoms + tenWithout,
            baseline: baseline
        ) else { return XCTFail() }

        XCTAssertEqual(signal.monthCharacter, .notableImprovement)
    }

    func testMonthCharacter_notablyHarder() {
        // Baseline avg: 5 symptom days/month → current 14 → ratio 2.8
        let current = (1...14).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-04-%02d", n)), symptoms: [.hotFlashes])
        }
        let baseline = (1...5).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-02-%02d", n)), symptoms: [.hotFlashes])
        } + (1...5).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-01-%02d", n)), symptoms: [.hotFlashes])
        }

        guard case .ready(let signal) = compute(current: current, baseline: baseline) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.monthCharacter, .notablyHarder)
    }

    func testMonthCharacter_similar() {
        // Baseline avg: 10/month → current 10 → ratio 1.0
        let current = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        let baseline = days(month: "2025-02", count: 10, symptoms: [.hotFlashes])
                     + days(month: "2025-01", count: 10, symptoms: [.hotFlashes])

        guard case .ready(let signal) = compute(current: current, baseline: baseline) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.monthCharacter, .similar)
    }

    // MARK: - Edge cases

    func testEdge_allSymptoms_maxDensity() {
        // Every symptom logged every day — engine should not crash, return top 3
        let allSymptoms = Set(Symptom.allCases)
        let current = (1...15).map { n -> CycleDay in
            CycleDay(date: makeDate(String(format: "2025-04-%02d", n)), symptoms: allSymptoms)
        }
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail("Engine crashed on max density")
        }
        XCTAssertLessThanOrEqual(signal.dominantSymptoms.filter { $0.trend != .resolved }.count, 3)
    }

    func testEdge_noSymptoms_noDominantSymptoms() {
        let current = days(month: "2025-04", count: 10)
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        XCTAssertTrue(signal.dominantSymptoms.isEmpty)
    }

    func testEdge_singleSymptomOnly() {
        let current = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        guard case .ready(let signal) = compute(current: current) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.dominantSymptoms.count, 1)
        XCTAssertEqual(signal.dominantSymptoms.first?.symptom, .hotFlashes)
    }

    func testEdge_zeroBaselineBurden_currentHasSymptoms() {
        // Baseline had no symptoms at all — current has some
        let current  = days(month: "2025-04", count: 10, symptoms: [.hotFlashes])
        let baseline = days(month: "2025-02", count: 10)
                     + days(month: "2025-01", count: 10)

        guard case .ready(let signal) = compute(current: current, baseline: baseline) else {
            return XCTFail()
        }
        XCTAssertEqual(signal.monthCharacter, .slightlyHarder)
    }
}
