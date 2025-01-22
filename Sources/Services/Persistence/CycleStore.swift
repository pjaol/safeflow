import Foundation
import Combine

@MainActor
class CycleStore: ObservableObject {
    @Published private(set) var cycleDays: [CycleDay] = []
    private let saveKey = "cycleDays"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadData()
    }
    
    private func loadData() {
        guard let data = userDefaults.data(forKey: saveKey),
              let decodedDays = try? JSONDecoder().decode([CycleDay].self, from: data) else {
            return
        }
        cycleDays = decodedDays
    }
    
    private func saveData() {
        guard let encoded = try? JSONEncoder().encode(cycleDays) else {
            return
        }
        userDefaults.set(encoded, forKey: saveKey)
        objectWillChange.send()
    }
    
    func addOrUpdateDay(_ cycleDay: CycleDay) {
        if let index = cycleDays.firstIndex(where: { $0.id == cycleDay.id }) {
            cycleDays[index] = cycleDay
        } else if let existingIndex = cycleDays.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: cycleDay.date) }) {
            // If there's already an entry for this date, update it
            cycleDays[existingIndex] = cycleDay
        } else {
            cycleDays.append(cycleDay)
        }
        saveData()
    }
    
    func deleteDay(id: UUID) {
        cycleDays.removeAll { $0.id == id }
        saveData()
    }
    
    #if DEBUG
    func clearAllData() {
        cycleDays.removeAll()
        userDefaults.removeObject(forKey: saveKey)
        objectWillChange.send()
    }
    #endif
    
    func getDaysInRange(start: Date, end: Date) -> [CycleDay] {
        cycleDays.filter { $0.date >= start && $0.date <= end }
    }
    
    func predictNextPeriod() -> Date? {
        guard cycleDays.count >= 2 else { return nil }
        
        let periodStarts = cycleDays
            .filter { $0.flow != nil }
            .map { $0.date }
            .sorted()
        
        guard periodStarts.count >= 2 else { return nil }
        
        let cycles = zip(periodStarts, periodStarts.dropFirst())
            .map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        
        let averageCycleLength = Double(cycles.reduce(0, +)) / Double(cycles.count)
        
        guard let lastPeriodStart = periodStarts.last else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(round(averageCycleLength)), to: lastPeriodStart)
    }
    
    func calculateAverageCycleLength() -> Int? {
        guard cycleDays.count >= 2 else { return nil }
        
        let periodStarts = cycleDays
            .filter { $0.flow != nil }
            .map { $0.date }
            .sorted()
        
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
    
    var recentDays: [CycleDay] {
        cycleDays.sorted { $0.date > $1.date }
    }
} 