import Foundation
import Combine

@MainActor
class CycleStore: ObservableObject {
    @Published private(set) var cycleDays: [CycleDay] = []
    private let saveKey = "cycleDays"
    private let userDefaults: UserDefaults
    private let store: PersistenceService
    
    init(userDefaults: UserDefaults = .standard, store: PersistenceService = .shared) {
        self.userDefaults = userDefaults
        self.store = store
        Task {
            await loadData()
        }
    }
    
    private func loadData() async {
        do {
            cycleDays = try await store.loadCycleDays()
        } catch {
            print("Error loading cycle data: \(error)")
            cycleDays = []
        }
    }
    
    private func saveData() async {
        do {
            try await store.saveCycleDays(cycleDays)
            objectWillChange.send()
        } catch {
            print("Error saving cycle data: \(error)")
        }
    }
    
    func addOrUpdateDay(_ cycleDay: CycleDay) {
        if let index = cycleDays.firstIndex(where: { $0.id == cycleDay.id }) {
            cycleDays[index] = cycleDay
        } else if let existingIndex = cycleDays.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: cycleDay.date) }) {
            cycleDays[existingIndex] = cycleDay
        } else {
            cycleDays.append(cycleDay)
        }
        
        objectWillChange.send()
        
        Task {
            await saveData()
        }
    }
    
    func deleteDay(id: UUID) {
        cycleDays.removeAll { $0.id == id }
        
        Task {
            await saveData()
        }
    }
    
    #if DEBUG
    func clearAllData() {
        cycleDays.removeAll()
        userDefaults.removeObject(forKey: saveKey)
        objectWillChange.send()
        
        Task {
            await saveData()
        }
    }
    #endif
    
    func getDaysInRange(start: Date, end: Date) -> [CycleDay] {
        cycleDays.filter { $0.date >= start && $0.date <= end }
    }
    
    func getAllDays() -> [CycleDay] {
        cycleDays
    }
    
    func predictNextPeriod() -> Date? {
        guard cycleDays.count >= 2 else { return nil }
        
        // Get days with flow, sorted by date
        let daysWithFlow = cycleDays
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }
        
        // Find period start dates by identifying the first day of each period
        var periodStarts: [Date] = []
        var lastPeriodEnd: Date? = nil
        
        for day in daysWithFlow {
            if let lastEnd = lastPeriodEnd {
                // If this day is more than 3 days after the last period ended,
                // consider it the start of a new period
                if Calendar.current.dateComponents([.day], from: lastEnd, to: day.date).day ?? 0 > 3 {
                    periodStarts.append(day.date)
                }
            } else {
                // First period start
                periodStarts.append(day.date)
            }
            
            lastPeriodEnd = day.date
        }
        
        guard periodStarts.count >= 2 else { return nil }
        
        let cycles = zip(periodStarts, periodStarts.dropFirst())
            .map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        
        let averageCycleLength = Double(cycles.reduce(0, +)) / Double(cycles.count)
        
        // Get the last period start that's not in the future
        let today = Calendar.current.startOfDay(for: Date())
        let lastPeriodStart = periodStarts
            .filter { $0 <= today }
            .last
        
        guard let lastStart = lastPeriodStart else { return nil }
        
        // Calculate the next prediction after today
        let daysFromLastStart = Calendar.current.dateComponents([.day], from: lastStart, to: today).day ?? 0
        let cyclesElapsed = Double(daysFromLastStart) / averageCycleLength
        let wholeCyclesElapsed = floor(cyclesElapsed)
        let nextCycleOffset = Int(round((wholeCyclesElapsed + 1.0) * averageCycleLength))
        
        return Calendar.current.date(byAdding: .day, value: nextCycleOffset, to: lastStart)
    }
    
    func calculateAverageCycleLength() -> Int? {
        guard cycleDays.count >= 2 else { return nil }
        
        // Get days with flow, sorted by date
        let daysWithFlow = cycleDays
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }
        
        // Find period start dates by identifying the first day of each period
        var periodStarts: [Date] = []
        var lastPeriodEnd: Date? = nil
        
        for day in daysWithFlow {
            if let lastEnd = lastPeriodEnd {
                // If this day is more than 3 days after the last period ended,
                // consider it the start of a new period
                if Calendar.current.dateComponents([.day], from: lastEnd, to: day.date).day ?? 0 > 3 {
                    periodStarts.append(day.date)
                }
            } else {
                // First period start
                periodStarts.append(day.date)
            }
            
            lastPeriodEnd = day.date
        }
        
        guard periodStarts.count >= 2 else { return nil }
        
        let cycles = zip(periodStarts, periodStarts.dropFirst())
            .map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        
        let averageCycleLength = Double(cycles.reduce(0, +)) / Double(cycles.count)
        return Int(round(averageCycleLength))
    }
    
    func getCurrentDay() -> CycleDay? {
        let today = Calendar.current.startOfDay(for: Date())
        return cycleDays.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    func getDay(for date: Date) -> CycleDay? {
        let targetDate = Calendar.current.startOfDay(for: date)
        return cycleDays.first { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
    }
    
    var recentDays: [CycleDay] {
        cycleDays.sorted { $0.date > $1.date }
    }
} 