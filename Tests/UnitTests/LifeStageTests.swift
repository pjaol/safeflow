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

// MARK: - DartboardCategory life-stage gating

final class DartboardCategoryGatingTests: XCTestCase {

    // MARK: - isVisible

    func testCoreCategorigesVisibleForAllStages() {
        let coreCategories: [DartboardCategory] = [.pain, .energy, .mood, .gut]
        for stage in LifeStage.allCases {
            for category in coreCategories {
                XCTAssertTrue(
                    category.isVisible(for: stage),
                    "\(category) should be visible for \(stage)"
                )
            }
        }
    }

    func testVasomotorVisibleOnlyForPerimenopauseAndMenopause() {
        XCTAssertFalse(DartboardCategory.vasomotor.isVisible(for: .regular))
        XCTAssertFalse(DartboardCategory.vasomotor.isVisible(for: .irregular))
        XCTAssertTrue(DartboardCategory.vasomotor.isVisible(for: .perimenopause))
        XCTAssertTrue(DartboardCategory.vasomotor.isVisible(for: .menopause))
        XCTAssertFalse(DartboardCategory.vasomotor.isVisible(for: .paused))
    }

    func testMusculoskeletalVisibleOnlyForPerimenopauseAndMenopause() {
        XCTAssertFalse(DartboardCategory.musculoskeletal.isVisible(for: .regular))
        XCTAssertFalse(DartboardCategory.musculoskeletal.isVisible(for: .irregular))
        XCTAssertTrue(DartboardCategory.musculoskeletal.isVisible(for: .perimenopause))
        XCTAssertTrue(DartboardCategory.musculoskeletal.isVisible(for: .menopause))
        XCTAssertFalse(DartboardCategory.musculoskeletal.isVisible(for: .paused))
    }

    // MARK: - visibleCategories counts

    func testRegularHasFourVisibleCategories() {
        let visible = DartboardCategory.allCases.filter { $0.isVisible(for: .regular) }
        XCTAssertEqual(visible.count, 4)
    }

    func testPerimenopauseHasSixVisibleCategories() {
        let visible = DartboardCategory.allCases.filter { $0.isVisible(for: .perimenopause) }
        XCTAssertEqual(visible.count, 6)
    }

    func testMenopauseHasSixVisibleCategories() {
        let visible = DartboardCategory.allCases.filter { $0.isVisible(for: .menopause) }
        XCTAssertEqual(visible.count, 6)
    }

    func testPausedHasFourVisibleCategories() {
        let visible = DartboardCategory.allCases.filter { $0.isVisible(for: .paused) }
        XCTAssertEqual(visible.count, 4)
    }

    // MARK: - symptomCategory mapping

    func testSymptomCategoryMappingIsComplete() {
        // Every non-mood category must map to a SymptomCategory
        for category in DartboardCategory.allCases where category != .mood {
            XCTAssertNotNil(
                category.symptomCategory,
                "\(category).symptomCategory should not be nil"
            )
        }
        XCTAssertNil(DartboardCategory.mood.symptomCategory)
    }

    func testVasomotorMapsToVasomotorSymptomCategory() {
        XCTAssertEqual(DartboardCategory.vasomotor.symptomCategory, .vasomotor)
    }

    func testMusculoskeletalMapsToMusculoskeletalSymptomCategory() {
        XCTAssertEqual(DartboardCategory.musculoskeletal.symptomCategory, .musculoskeletal)
    }
}

// MARK: - SymptomCategory life-stage visibility

final class SymptomCategoryVisibilityTests: XCTestCase {

    func testVasomotorVisibleForPerimenopauseAndMenopause() {
        XCTAssertFalse(SymptomCategory.vasomotor.visibleForStages.contains(.regular))
        XCTAssertFalse(SymptomCategory.vasomotor.visibleForStages.contains(.irregular))
        XCTAssertTrue(SymptomCategory.vasomotor.visibleForStages.contains(.perimenopause))
        XCTAssertTrue(SymptomCategory.vasomotor.visibleForStages.contains(.menopause))
        XCTAssertFalse(SymptomCategory.vasomotor.visibleForStages.contains(.paused))
    }

    func testMusculoskeletalVisibleForPerimenopauseAndMenopause() {
        XCTAssertTrue(SymptomCategory.musculoskeletal.visibleForStages.contains(.perimenopause))
        XCTAssertTrue(SymptomCategory.musculoskeletal.visibleForStages.contains(.menopause))
        XCTAssertFalse(SymptomCategory.musculoskeletal.visibleForStages.contains(.regular))
    }

    func testIntimateHealthVisibleForMenopauseOnly() {
        XCTAssertTrue(SymptomCategory.intimateHealth.visibleForStages.contains(.menopause))
        XCTAssertFalse(SymptomCategory.intimateHealth.visibleForStages.contains(.perimenopause))
        XCTAssertFalse(SymptomCategory.intimateHealth.visibleForStages.contains(.regular))
        XCTAssertFalse(SymptomCategory.intimateHealth.visibleForStages.contains(.paused))
    }

    func testCoreCategoriesVisibleForAllStages() {
        let coreCategories: [SymptomCategory] = [.pain, .energy, .digestive]
        for category in coreCategories {
            XCTAssertEqual(
                category.visibleForStages,
                Set(LifeStage.allCases),
                "\(category) should be visible for all life stages"
            )
        }
    }
}

