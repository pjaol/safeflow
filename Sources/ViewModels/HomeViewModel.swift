import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published private(set) var currentCycleDay: CycleDay?
    @Published private(set) var predictedNextPeriod: Date?
    @Published private(set) var recentDays: [CycleDay] = []
    
    private let cycleStore: CycleStore
    private var cancellables = Set<AnyCancellable>()
    
    init(cycleStore: CycleStore) {
        self.cycleStore = cycleStore
        setupSubscriptions()
        updateCurrentDay()
    }
    
    private func setupSubscriptions() {
        cycleStore.$cycleDays
            .sink { [weak self] _ in
                self?.updateCurrentDay()
                self?.updatePredictions()
                self?.updateRecentDays()
            }
            .store(in: &cancellables)
    }
    
    private func updateCurrentDay() {
        let today = Calendar.current.startOfDay(for: Date())
        currentCycleDay = cycleStore.cycleDays.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    private func updatePredictions() {
        predictedNextPeriod = cycleStore.predictNextPeriod()
    }
    
    private func updateRecentDays() {
        let today = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: today)!
        recentDays = cycleStore.getDaysInRange(start: thirtyDaysAgo, end: today)
            .sorted { $0.date > $1.date }
    }
    
    func logDay(flow: FlowIntensity?, symptoms: Set<Symptom>, mood: Mood?, notes: String?) {
        let today = Calendar.current.startOfDay(for: Date())
        let cycleDay = CycleDay(date: today, flow: flow, symptoms: symptoms, mood: mood, notes: notes)
        cycleStore.addOrUpdateDay(cycleDay)
    }
    
    func deleteDay(id: UUID) {
        cycleStore.deleteDay(id: id)
    }
    
    var averageCycleLength: Int? {
        guard let periodStarts = getPeriodStartDates(), periodStarts.count >= 2 else { return nil }
        
        let cycles = zip(periodStarts, periodStarts.dropFirst())
            .map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        
        return Int(round(Double(cycles.reduce(0, +)) / Double(cycles.count)))
    }
    
    private func getPeriodStartDates() -> [Date]? {
        let periodStarts = cycleStore.cycleDays
            .filter { $0.flow != nil }
            .map { $0.date }
            .sorted()
        
        return periodStarts.isEmpty ? nil : periodStarts
    }
} 