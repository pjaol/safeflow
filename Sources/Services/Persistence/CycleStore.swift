import Foundation
import Combine
import SwiftUI

@MainActor
class CycleStore: ObservableObject {
    @Published private(set) var cycleDays: [CycleDay] = []
    @Published private(set) var seedData: CycleSeedData?

    private let store: PersistenceService
    private let dateProvider: () -> Date
    private let engine = CyclePredictionEngine()
    private let symptomEngine = SymptomPatternEngine()

    private static let seedDataKey = "cycleSeedData"

    // MARK: - Init

    /// Production initialiser — uses the real clock and shared persistence.
    init(store: PersistenceService = .shared) {
        self.store = store
        self.dateProvider = { Date() }
        Task { await loadData() }
    }

    /// Test initialiser — accepts an injected persistence service and a fixed
    /// date so every algorithm method is fully deterministic in unit tests.
    init(store: PersistenceService, dateProvider: @escaping () -> Date) {
        self.store = store
        self.dateProvider = dateProvider
        Task { await loadData() }
    }

    // MARK: - Persistence

    private func loadData() async {
        do {
            cycleDays = try await store.loadCycleDays()
            seedData = try await store.loadSeedData()
        } catch {
            print("Error loading cycle data: \(error)")
            cycleDays = []
        }
    }

    private func saveData() async {
        do {
            try await store.saveCycleDays(cycleDays)
            if let seed = seedData {
                try await store.saveSeedData(seed)
            }
            objectWillChange.send()
        } catch {
            print("Error saving cycle data: \(error)")
        }
    }

    // MARK: - CRUD

    func addOrUpdateDay(_ cycleDay: CycleDay) {
        if let index = cycleDays.firstIndex(where: { $0.id == cycleDay.id }) {
            cycleDays[index] = cycleDay
        } else if let existingIndex = cycleDays.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: cycleDay.date) }) {
            cycleDays[existingIndex] = cycleDay
        } else {
            cycleDays.append(cycleDay)
        }
        objectWillChange.send()
        Task { await saveData() }
        // Cancel reminder if a period was just logged (user beat the prediction)
        if cycleDay.flow != nil {
            Task { await NotificationService.shared.cancelSupplyReminder() }
        }
        rescheduleSupplyReminder()
    }

    func deleteDay(id: UUID) {
        cycleDays.removeAll { $0.id == id }
        Task { await saveData() }
    }

    func saveSeedData(_ seed: CycleSeedData) {
        seedData = seed
        Task { await saveData() }
    }

    #if DEBUG
    func clearAllData() {
        cycleDays.removeAll()
        seedData = nil
        objectWillChange.send()
        Task { await saveData() }
    }
    #endif

    // MARK: - Queries

    func getDaysInRange(start: Date, end: Date) -> [CycleDay] {
        cycleDays.filter { $0.date >= start && $0.date <= end }
    }

    func getAllDays() -> [CycleDay] { cycleDays }

    func getCurrentDay() -> CycleDay? {
        let today = Calendar.current.startOfDay(for: dateProvider())
        return cycleDays.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func getDay(for date: Date) -> CycleDay? {
        let target = Calendar.current.startOfDay(for: date)
        return cycleDays.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
    }

    var recentDays: [CycleDay] {
        cycleDays.sorted { $0.date > $1.date }
    }

    // MARK: - Prediction & Phase (delegates to CyclePredictionEngine)

    func predictNextPeriod() -> Date? {
        engine.predictNextPeriod(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func predictNextPeriodRange() -> (earliest: Date, latest: Date)? {
        engine.predictNextPeriodRange(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func calculateAverageCycleLength() -> Int? {
        engine.averageCycleLength(from: cycleDays)
    }

    func cycleVariability() -> Double? {
        let starts = engine.extractPeriodStarts(from: cycleDays)
        let lengths = engine.cycleLengths(from: starts)
        return engine.cycleVariability(from: lengths)
    }

    func currentPhase() -> CyclePhase? {
        engine.currentPhase(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func currentCycleDayNumber() -> Int? {
        engine.currentCycleDayNumber(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func estimatedOvulationDate() -> Date? {
        engine.estimatedOvulationDate(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func fertileWindow() -> DateInterval? {
        engine.fertileWindow(days: cycleDays, seedData: seedData, today: dateProvider())
    }

    func forecastCycles(count: Int) -> [CycleForecast] {
        engine.forecastCycles(count: count, days: cycleDays, seedData: seedData, today: dateProvider())
    }

    // MARK: - Notification Scheduling

    /// Re-schedules the supply reminder based on the current next-period prediction.
    /// Safe to call frequently — the notification service replaces any existing reminder.
    func rescheduleSupplyReminder() {
        guard let range = predictNextPeriodRange() else { return }
        Task { await NotificationService.shared.scheduleSupplyReminder(periodEarliest: range.earliest) }
    }

    // MARK: - Pattern Nudge

    /// Returns the highest-priority undismissed nudge for the current data, or nil.
    func currentNudge() -> CycleNudge? {
        let evaluator = ContentEvaluator(store: self)
        guard let nudge = evaluator.activeNudge(dismissed: DismissedNudges.load()) else { return nil }
        return CycleNudge(
            id: nudge.id,
            sfSymbol: nudge.sfSymbol,
            title: nudge.title,
            body: nudge.body,
            backgroundColor: nudge.type == "comfort"
                ? AppTheme.Colors.nudgeComfortBackground
                : AppTheme.Colors.nudgeHealthBackground,
            dismissible: nudge.dismissible
        )
    }

    // MARK: - Symptom Pattern Insights

    /// Returns today's rotating insight based on personal symptom/mood patterns
    /// and population context from the content pipeline.
    /// Returns nil when there isn't enough data yet.
    func todayInsight() -> SymptomInsight? {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: dateProvider()) ?? 1
        let phase = currentPhase()
        // No meaningful phase-anchored insight when the cycle is overdue
        guard phase != nil else { return nil }
        let evaluator = ContentEvaluator(store: self)

        // Build insights using personal pattern engine but population norms from content pipeline
        var results: [SymptomInsight] = []
        for p in CyclePhase.allCases {
            let top = symptomEngine.topSymptoms(
                phase: p,
                cycleDays: cycleDays,
                seedData: seedData,
                predictionEngine: engine,
                today: dateProvider()
            )
            for (symptom, freq) in top {
                let norm = evaluator.populationNorm(symptom: symptom, phase: p)
                results.append(SymptomInsight(
                    symptom: symptom,
                    phase: p,
                    personalFrequency: freq,
                    populationNorm: norm,
                    kind: .personalPattern
                ))
            }
            if let valence = symptomEngine.moodValence(
                phase: p,
                cycleDays: cycleDays,
                seedData: seedData,
                predictionEngine: engine,
                today: dateProvider()
            ) {
                let norm = evaluator.moodNorm(phase: p, valence: valence.dominant.valence)
                results.append(SymptomInsight(
                    symptom: nil,
                    phase: p,
                    personalFrequency: valence.dominant.frequency,
                    populationNorm: norm,
                    kind: .moodPattern(valence: valence.dominant.valence)
                ))
            }
        }

        // Prioritise current phase first, then by personal frequency
        let prioritised = results.sorted {
            if $0.phase == phase && $1.phase != phase { return true }
            if $1.phase == phase && $0.phase != phase { return false }
            return $0.personalFrequency > $1.personalFrequency
        }

        guard !prioritised.isEmpty else { return nil }
        return prioritised[dayIndex % prioritised.count]
    }

    /// Returns any active severity signals (escalating symptoms, phase-inconsistent patterns).
    func severitySignals() -> [SeveritySignal] {
        let evaluator = ContentEvaluator(store: self)
        return evaluator.activeSignals(dismissed: DismissedNudges.load()).map { signal in
            SeveritySignal(
                id: signal.id,
                symptom: nil,
                title: signal.title,
                body: signal.body,
                priority: signal.priority == "high" ? .high : .medium
            )
        }
    }
}
