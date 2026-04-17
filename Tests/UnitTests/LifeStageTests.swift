import XCTest
@testable import safeflow

final class LifeStageTests: XCTestCase {

    // MARK: - Persistence helpers

    private func makeDefaults(suiteName: String = #function) -> UserDefaults {
        let d = UserDefaults(suiteName: suiteName)!
        d.removePersistentDomain(forName: suiteName)
        return d
    }

    // MARK: - Default value

    func testDefaultLifeStageIsRegular() {
        let defaults = makeDefaults()
        // No value written — reading should fall back to .regular
        let raw = defaults.string(forKey: LifeStage.defaultsKey)
        XCTAssertNil(raw, "No value should be set before first launch")

        let stage = raw.flatMap(LifeStage.init(rawValue:)) ?? .regular
        XCTAssertEqual(stage, .regular)
    }

    // MARK: - Persistence round-trip

    func testPersistenceRoundTrip() {
        let defaults = makeDefaults()

        for stage in LifeStage.allCases {
            defaults.set(stage.rawValue, forKey: LifeStage.defaultsKey)
            let raw = defaults.string(forKey: LifeStage.defaultsKey)
            let decoded = raw.flatMap(LifeStage.init(rawValue:))
            XCTAssertEqual(decoded, stage, "Round-trip failed for \(stage)")
        }
    }

    func testUnknownRawValueFallsBackToRegular() {
        let decoded = LifeStage(rawValue: "future_unknown_stage")
        XCTAssertNil(decoded, "Unknown raw values should decode to nil so call sites can apply their own default")
    }

    // MARK: - Feature flags

    func testShowsCyclePrediction() {
        XCTAssertTrue(LifeStage.regular.showsCyclePrediction)
        XCTAssertTrue(LifeStage.irregular.showsCyclePrediction)
        XCTAssertFalse(LifeStage.perimenopause.showsCyclePrediction)
        XCTAssertFalse(LifeStage.menopause.showsCyclePrediction)
        XCTAssertFalse(LifeStage.paused.showsCyclePrediction)
    }

    func testShowsBleedHistory() {
        XCTAssertFalse(LifeStage.regular.showsBleedHistory)
        XCTAssertFalse(LifeStage.irregular.showsBleedHistory)
        XCTAssertTrue(LifeStage.perimenopause.showsBleedHistory)
        XCTAssertFalse(LifeStage.menopause.showsBleedHistory)
        XCTAssertFalse(LifeStage.paused.showsBleedHistory)
    }

    func testFlowSliderIsSecondary() {
        XCTAssertFalse(LifeStage.regular.flowSliderIsSecondary)
        XCTAssertFalse(LifeStage.irregular.flowSliderIsSecondary)
        XCTAssertFalse(LifeStage.perimenopause.flowSliderIsSecondary)
        XCTAssertTrue(LifeStage.menopause.flowSliderIsSecondary)
        XCTAssertTrue(LifeStage.paused.flowSliderIsSecondary)
    }

    // MARK: - CaseIterable completeness

    func testAllCasesCount() {
        XCTAssertEqual(LifeStage.allCases.count, 5)
    }

    func testAllCasesHaveNonEmptyLocalizedStrings() {
        for stage in LifeStage.allCases {
            XCTAssertFalse(stage.localizedNameString.isEmpty, "\(stage).localizedNameString is empty")
        }
    }

    // MARK: - PausedContext

    func testPausedContextRoundTrip() {
        let defaults = makeDefaults()

        defaults.set(PausedContext.recovering.rawValue, forKey: PausedContext.defaultsKey)
        let raw = defaults.string(forKey: PausedContext.defaultsKey)
        XCTAssertEqual(PausedContext(rawValue: raw ?? ""), .recovering)

        defaults.set(PausedContext.notTracking.rawValue, forKey: PausedContext.defaultsKey)
        let raw2 = defaults.string(forKey: PausedContext.defaultsKey)
        XCTAssertEqual(PausedContext(rawValue: raw2 ?? ""), .notTracking)
    }
}
