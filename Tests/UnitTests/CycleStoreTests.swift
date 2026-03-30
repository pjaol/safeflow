import XCTest
@testable import safeflow

// MARK: - Helpers

private func makeDate(_ string: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f.date(from: string)!
}

private func makeStore(
    referenceDate: Date = makeDate("2025-03-15"),
    suiteName: String = #file
) -> CycleStore {
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let persistence = PersistenceService(userDefaults: defaults)
    return CycleStore(store: persistence, dateProvider: { referenceDate })
}

/// Waits long enough for the internal async save Task to complete.
private func drain() async {
    try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
}

// MARK: - CycleStoreTests

final class CycleStoreTests: XCTestCase {

    // MARK: - CRUD

    func testAddDay() async {
        let sut = makeStore()
        let day = CycleDay(date: makeDate("2025-03-15"), flow: .medium, symptoms: [.cramps], mood: .happy)

        sut.addOrUpdateDay(day)
        await drain()

        XCTAssertEqual(sut.cycleDays.count, 1)
        XCTAssertEqual(sut.cycleDays.first?.flow, .medium)
        XCTAssertEqual(sut.cycleDays.first?.mood, .happy)
    }

    func testUpdateDay() async {
        let sut = makeStore()
        let id = UUID()
        let date = makeDate("2025-03-15")

        sut.addOrUpdateDay(CycleDay(id: id, date: date, flow: .light))
        sut.addOrUpdateDay(CycleDay(id: id, date: date, flow: .heavy))
        await drain()

        XCTAssertEqual(sut.cycleDays.count, 1)
        XCTAssertEqual(sut.cycleDays.first?.flow, .heavy)
    }

    func testDeleteDay() async {
        let sut = makeStore()
        let day = CycleDay(date: makeDate("2025-03-15"), flow: .medium)

        sut.addOrUpdateDay(day)
        await drain()
        sut.deleteDay(id: day.id)
        await drain()

        XCTAssertTrue(sut.cycleDays.isEmpty)
    }

    func testGetDaysInRange() async {
        let sut = makeStore()
        let days = [
            CycleDay(date: makeDate("2025-03-15"), flow: .medium),
            CycleDay(date: makeDate("2025-03-14"), flow: .light),
            CycleDay(date: makeDate("2025-03-13"), flow: .heavy),
            CycleDay(date: makeDate("2025-03-12"), flow: .spotting)
        ]
        for d in days { sut.addOrUpdateDay(d) }
        await drain()

        let result = sut.getDaysInRange(start: makeDate("2025-03-14"), end: makeDate("2025-03-15"))
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Seed Data

    func testSaveSeedData() async {
        let sut = makeStore()
        let seed = CycleSeedData(
            lastPeriodStartDate: makeDate("2025-03-01"),
            typicalPeriodLength: 5,
            typicalCycleLength: 28
        )
        sut.saveSeedData(seed)
        await drain()

        XCTAssertEqual(sut.seedData?.typicalCycleLength, 28)
    }

    // MARK: - CyclePredictionEngine: Period Detection

    func testSpottingOnlyDoesNotStartPeriod() {
        let engine = CyclePredictionEngine()
        let days = [
            CycleDay(date: makeDate("2025-01-10"), flow: .spotting),
            CycleDay(date: makeDate("2025-02-07"), flow: .medium),
            CycleDay(date: makeDate("2025-02-08"), flow: .heavy),
        ]
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 1, "Single spotting day should not count as a period start")
        XCTAssertEqual(starts.first, Calendar.current.startOfDay(for: makeDate("2025-02-07")))
    }

    func testTwoConsecutiveFlowDaysStartPeriod() {
        let engine = CyclePredictionEngine()
        let days = [
            CycleDay(date: makeDate("2025-01-05"), flow: .light),
            CycleDay(date: makeDate("2025-01-06"), flow: .medium),
        ]
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 1)
    }

    func testSpottingFollowedByRealPeriodCountsOnce() {
        let engine = CyclePredictionEngine()
        // Spotting on day X then real period starts 1 day later — same run
        let days = [
            CycleDay(date: makeDate("2025-01-05"), flow: .spotting),
            CycleDay(date: makeDate("2025-01-06"), flow: .medium),
            CycleDay(date: makeDate("2025-01-07"), flow: .heavy),
        ]
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 1)
    }

    // MARK: - CyclePredictionEngine: Weighted Average

    func testWeightedAverageWithTwoCycles() {
        let engine = CyclePredictionEngine()
        // lengths [28, 30] → weights [1, 2] → (28*1 + 30*2) / 3 = 88/3 ≈ 29.33
        let result = engine.weightedAverageCycleLength(from: [28, 30])
        XCTAssertEqual(result, (28.0 * 1 + 30.0 * 2) / 3.0, accuracy: 0.01)
    }

    func testWeightedAverageWithSixCycles() {
        let engine = CyclePredictionEngine()
        let lengths = [26, 28, 30, 27, 29, 31]
        // weights [1,2,3,4,5,6], sum=21
        let expected = (26.0*1 + 28.0*2 + 30.0*3 + 27.0*4 + 29.0*5 + 31.0*6) / 21.0
        XCTAssertEqual(engine.weightedAverageCycleLength(from: lengths), expected, accuracy: 0.01)
    }

    func testWeightedAverageDropsOlderThanSix() {
        let engine = CyclePredictionEngine()
        // 7 cycles — only last 6 should be used
        let lengths = [99, 26, 28, 30, 27, 29, 31]
        let sixOnly = [26, 28, 30, 27, 29, 31]
        XCTAssertEqual(
            engine.weightedAverageCycleLength(from: lengths),
            engine.weightedAverageCycleLength(from: sixOnly),
            accuracy: 0.01
        )
    }

    func testWeightedAverageReturnsPopulationPriorForOneCycle() {
        let engine = CyclePredictionEngine()
        XCTAssertEqual(engine.weightedAverageCycleLength(from: [28]), CyclePredictionEngine.populationMeanCycleLength)
    }

    func testWeightedAverageReturnsPopulationPriorForNoCycles() {
        let engine = CyclePredictionEngine()
        XCTAssertEqual(engine.weightedAverageCycleLength(from: []), CyclePredictionEngine.populationMeanCycleLength)
    }

    // MARK: - CyclePredictionEngine: Variability

    func testCycleVariabilityKnownVariance() {
        let engine = CyclePredictionEngine()
        // lengths [26, 28, 30] → mean 28, variance = ((4+0+4)/2) = 4, sigma = 2
        let result = engine.cycleVariability(from: [26, 28, 30])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 2.0, accuracy: 0.01)
    }

    func testCycleVariabilityNilForSingleCycle() {
        let engine = CyclePredictionEngine()
        XCTAssertNil(engine.cycleVariability(from: [28]))
    }

    // MARK: - CyclePredictionEngine: Phase

    func testCurrentPhaseMenstrual() {
        let engine = CyclePredictionEngine()
        // today = day 2 of cycle (1 day after period start)
        let periodStart = makeDate("2025-03-14")
        let today = makeDate("2025-03-15")
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-15"), flow: .medium),
            // Prior period to give engine a cycle length
            CycleDay(date: makeDate("2025-02-14"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-15"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let phase = engine.currentPhase(days: days, seedData: seed, today: today)
        XCTAssertEqual(phase, .menstrual)
    }

    func testCurrentPhaseFollicular() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-01")
        let today = makeDate("2025-03-09") // day 9
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-02"), flow: .medium),
            CycleDay(date: makeDate("2025-02-01"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-02"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let phase = engine.currentPhase(days: days, seedData: seed, today: today)
        XCTAssertEqual(phase, .follicular)
    }

    func testCurrentPhaseOvulatory() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-01")
        let today = makeDate("2025-03-14") // day 14 — ovulation day for 28d cycle
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-02"), flow: .medium),
            CycleDay(date: makeDate("2025-02-01"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-02"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let phase = engine.currentPhase(days: days, seedData: seed, today: today)
        XCTAssertEqual(phase, .ovulatory)
    }

    func testCurrentPhaseLuteal() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-01")
        let today = makeDate("2025-03-20") // day 20 — luteal
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-02"), flow: .medium),
            CycleDay(date: makeDate("2025-02-01"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-02"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let phase = engine.currentPhase(days: days, seedData: seed, today: today)
        XCTAssertEqual(phase, .luteal)
    }

    // MARK: - CyclePredictionEngine: Fertile Window

    func testFertileWindowSpansSixDays() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-01")
        let today = makeDate("2025-03-08")
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-02"), flow: .medium),
            CycleDay(date: makeDate("2025-02-01"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-02"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let window = engine.fertileWindow(days: days, seedData: seed, today: today)
        XCTAssertNotNil(window)
        if let window {
            let days = Calendar.current.dateComponents([.day], from: window.start, to: window.end).day ?? 0
            XCTAssertEqual(days, 5, "Fertile window should span 5 days (start through ovulation = 6 inclusive)")
        }
    }

    func testEstimatedOvulationFor28DayCycle() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-01")
        let today = makeDate("2025-03-08")
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-02"), flow: .medium),
            CycleDay(date: makeDate("2025-02-01"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-02"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let ovulation = engine.estimatedOvulationDate(days: days, seedData: seed, today: today)
        // Expected: March 1 + (28 - 14) = March 15
        let expected = Calendar.current.startOfDay(for: makeDate("2025-03-15"))
        XCTAssertEqual(ovulation, expected)
    }

    // MARK: - CyclePredictionEngine: Prediction Range

    func testPredictionRangeWithKnownVariability() {
        let engine = CyclePredictionEngine()
        // Three cycles of lengths 26, 28, 30 → sigma = 2, halfWindow = ceil(2/2) = 1
        let periodStart1 = makeDate("2024-11-01")
        let periodStart2 = makeDate("2024-11-27") // 26 days later
        let periodStart3 = makeDate("2024-12-25") // 28 days later
        let periodStart4 = makeDate("2025-01-24") // 30 days later
        let today = makeDate("2025-01-30")

        let days = [
            CycleDay(date: periodStart1, flow: .heavy),
            CycleDay(date: Calendar.current.date(byAdding: .day, value: 1, to: periodStart1)!, flow: .medium),
            CycleDay(date: periodStart2, flow: .heavy),
            CycleDay(date: Calendar.current.date(byAdding: .day, value: 1, to: periodStart2)!, flow: .medium),
            CycleDay(date: periodStart3, flow: .heavy),
            CycleDay(date: Calendar.current.date(byAdding: .day, value: 1, to: periodStart3)!, flow: .medium),
            CycleDay(date: periodStart4, flow: .heavy),
            CycleDay(date: Calendar.current.date(byAdding: .day, value: 1, to: periodStart4)!, flow: .medium),
        ]

        let range = engine.predictNextPeriodRange(days: days, seedData: nil, today: today)
        XCTAssertNotNil(range)
        if let range {
            let width = Calendar.current.dateComponents([.day], from: range.earliest, to: range.latest).day ?? 0
            XCTAssertGreaterThanOrEqual(width, 2, "Range should be at least 2 days wide")
        }
    }

    func testPredictionRangeWithNoDataUsesPopulationPrior() {
        let engine = CyclePredictionEngine()
        let seed = CycleSeedData(
            lastPeriodStartDate: makeDate("2025-02-14"),
            typicalPeriodLength: 5,
            typicalCycleLength: 28
        )
        let range = engine.predictNextPeriodRange(days: [], seedData: seed, today: makeDate("2025-03-01"))
        XCTAssertNotNil(range, "Should produce a range using seed data as fallback")
    }

    // MARK: - CycleDayNumber

    func testCycleDayNumber() {
        let engine = CyclePredictionEngine()
        let periodStart = makeDate("2025-03-10")
        let today = makeDate("2025-03-15") // 5 days later → day 6
        let days = [
            CycleDay(date: periodStart, flow: .heavy),
            CycleDay(date: makeDate("2025-03-11"), flow: .medium),
        ]
        let seed = CycleSeedData(lastPeriodStartDate: periodStart, typicalPeriodLength: 5, typicalCycleLength: 28)
        let dayNumber = engine.currentCycleDayNumber(days: days, seedData: seed, today: today)
        XCTAssertEqual(dayNumber, 6)
    }

    // MARK: - CycleStore integration (uses date-injected store)

    func testPredictNextPeriodWithThirtyDayCycle() async {
        let today = makeDate("2025-03-15")
        let sut = makeStore(referenceDate: today)

        // Two complete 30-day periods ending before today
        let days = [
            CycleDay(date: makeDate("2025-01-14"), flow: .heavy),
            CycleDay(date: makeDate("2025-01-15"), flow: .medium),
            CycleDay(date: makeDate("2025-02-13"), flow: .heavy),
            CycleDay(date: makeDate("2025-02-14"), flow: .medium),
        ]
        for d in days { sut.addOrUpdateDay(d) }
        await drain()

        let prediction = sut.predictNextPeriod()
        XCTAssertNotNil(prediction)
    }

    func testPredictNextPeriodWithInsufficientData() async {
        let sut = makeStore()
        sut.addOrUpdateDay(CycleDay(date: makeDate("2025-03-15"), flow: .medium))
        await drain()

        XCTAssertNil(sut.predictNextPeriod())
    }

    func testCurrentPhaseFromStore() async {
        let today = makeDate("2025-03-15")
        let sut = makeStore(referenceDate: today)

        let seed = CycleSeedData(
            lastPeriodStartDate: makeDate("2025-03-14"),
            typicalPeriodLength: 5,
            typicalCycleLength: 28
        )
        sut.saveSeedData(seed)
        sut.addOrUpdateDay(CycleDay(date: makeDate("2025-03-14"), flow: .heavy))
        sut.addOrUpdateDay(CycleDay(date: makeDate("2025-03-15"), flow: .medium))
        sut.addOrUpdateDay(CycleDay(date: makeDate("2025-02-14"), flow: .heavy))
        sut.addOrUpdateDay(CycleDay(date: makeDate("2025-02-15"), flow: .medium))
        await drain()

        XCTAssertEqual(sut.currentPhase(), .menstrual)
    }
}
