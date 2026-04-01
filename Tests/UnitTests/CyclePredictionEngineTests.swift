import XCTest
@testable import safeflow

// MARK: - Helpers

private let engine = CyclePredictionEngine()

private func date(_ string: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f.date(from: string)!
}

/// Builds a minimal period: `count` days of flow starting on `start`.
private func period(start: String, days: Int = 3) -> [CycleDay] {
    (0..<days).map { offset in
        let d = Calendar.current.date(byAdding: .day, value: offset, to: date(start))!
        return CycleDay(id: UUID(), date: d, flow: .medium, symptoms: [], mood: nil, notes: nil)
    }
}

// MARK: - Period Detection

final class PeriodDetectionTests: XCTestCase {

    func testSinglePeriodDetected() {
        let days = period(start: "2025-01-01")
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(starts[0], date("2025-01-01"))
    }

    func testSpottingOnlyNotCounted() {
        let spotDay = CycleDay(id: UUID(), date: date("2025-01-01"), flow: .spotting, symptoms: [], mood: nil, notes: nil)
        XCTAssertTrue(engine.extractPeriodStarts(from: [spotDay]).isEmpty)
    }

    func testTwoPeriodsWithGapDetected() {
        let days = period(start: "2025-01-01") + period(start: "2025-01-29")
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 2)
    }

    func testConsecutiveFlowDaysWithSmallGapMergedIntoOnePeriod() {
        // 3-day gap is within periodGapDays=3, should merge into one period
        let days = period(start: "2025-01-01") + period(start: "2025-01-04")
        let starts = engine.extractPeriodStarts(from: days)
        XCTAssertEqual(starts.count, 1)
    }
}

// MARK: - Cycle Length

final class CycleLengthTests: XCTestCase {

    func testCycleLengthBetweenTwoPeriods() {
        let starts = [date("2025-01-01"), date("2025-01-29")]
        XCTAssertEqual(engine.cycleLengths(from: starts), [28])
    }

    func testWeightedAverageFavorsRecentCycles() {
        // Older: 28, newer: 35 — weighted avg should be closer to 35
        let lengths = [28, 28, 28, 35]
        let avg = engine.weightedAverageCycleLength(from: lengths)
        XCTAssertGreaterThan(avg, 30.0)
    }

    func testWeightedAverageFallsBackToSeedPrior() {
        let avg = engine.weightedAverageCycleLength(from: [28], seedPrior: 30.0)
        XCTAssertEqual(avg, 30.0)
    }

    func testWeightedAverageFallsBackToPopulationMean() {
        let avg = engine.weightedAverageCycleLength(from: [])
        XCTAssertEqual(avg, CyclePredictionEngine.populationMeanCycleLength)
    }

    func testCycleVariabilityNilForSingleLength() {
        XCTAssertNil(engine.cycleVariability(from: [28]))
    }

    func testCycleVariabilityComputedForMultipleLengths() {
        let sd = engine.cycleVariability(from: [28, 30, 26, 32])
        XCTAssertNotNil(sd)
        XCTAssertGreaterThan(sd!, 0)
    }
}

// MARK: - Phase

final class CyclePhaseTests: XCTestCase {

    // 5 cycles of 28 days so engine has real avg
    private func regularDays() -> [CycleDay] {
        let starts = ["2024-08-01", "2024-08-29", "2024-09-26", "2024-10-24", "2024-11-21"]
        return starts.flatMap { period(start: $0) }
    }

    func testMenstrualPhaseOnDay1() {
        let days = regularDays()
        // "2024-11-21" is the last period start → day 1 = menstrual
        let phase = engine.currentPhase(days: days, seedData: nil, today: date("2024-11-21"))
        XCTAssertEqual(phase, .menstrual)
    }

    func testLutealPhaseInLateWindow() {
        let days = regularDays()
        // day 20 of a 28-day cycle = luteal
        let today = Calendar.current.date(byAdding: .day, value: 19, to: date("2024-11-21"))!
        let phase = engine.currentPhase(days: days, seedData: nil, today: today)
        XCTAssertEqual(phase, .luteal)
    }

    func testPhaseNilWhenOverdue() {
        let days = regularDays()
        // 70 days after last period start — well past 28-day avg
        let today = Calendar.current.date(byAdding: .day, value: 70, to: date("2024-11-21"))!
        let phase = engine.currentPhase(days: days, seedData: nil, today: today)
        XCTAssertNil(phase, "Phase should be nil when cycle is overdue")
    }

    func testCycleDayNilWhenOverdue() {
        let days = regularDays()
        let today = Calendar.current.date(byAdding: .day, value: 70, to: date("2024-11-21"))!
        let dayNumber = engine.currentCycleDayNumber(days: days, seedData: nil, today: today)
        XCTAssertNil(dayNumber, "Day number should be nil when cycle is overdue")
    }

    func testPhaseNilWithNoData() {
        XCTAssertNil(engine.currentPhase(days: [], seedData: nil, today: date("2025-01-01")))
    }
}

// MARK: - Prediction

final class CyclePredictionTests: XCTestCase {

    private func regularDays() -> [CycleDay] {
        let starts = ["2025-01-01", "2025-01-29", "2025-02-26", "2025-03-26"]
        return starts.flatMap { period(start: $0) }
    }

    func testNextPeriodPredictedAfterLastStart() {
        let days = regularDays()
        let next = engine.predictNextPeriod(days: days, seedData: nil, today: date("2025-04-01"))
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, date("2025-03-26"))
    }

    func testPredictionRangeEarliestBeforeLatest() {
        let days = regularDays()
        let range = engine.predictNextPeriodRange(days: days, seedData: nil, today: date("2025-04-01"))
        XCTAssertNotNil(range)
        XCTAssertLessThan(range!.earliest, range!.latest)
    }

    func testForecastReturnsRequestedCount() {
        let days = regularDays()
        let forecasts = engine.forecastCycles(count: 4, days: days, seedData: nil, today: date("2025-04-01"))
        XCTAssertEqual(forecasts.count, 4)
    }

    func testForecastConfidenceFadesOverTime() {
        let days = regularDays()
        let forecasts = engine.forecastCycles(count: 6, days: days, seedData: nil, today: date("2025-04-01"))
        XCTAssertGreaterThan(forecasts[0].confidence, forecasts[5].confidence)
    }

    func testPredictionNilWithNoData() {
        XCTAssertNil(engine.predictNextPeriod(days: [], seedData: nil, today: date("2025-01-01")))
    }

    func testSeedDataUsedWhenNoLoggedPeriods() {
        let seed = CycleSeedData(
            lastPeriodStartDate: date("2025-01-01"),
            typicalPeriodLength: 5,
            typicalCycleLength: 28
        )
        let next = engine.predictNextPeriod(days: [], seedData: seed, today: date("2025-01-15"))
        XCTAssertNotNil(next)
    }
}
