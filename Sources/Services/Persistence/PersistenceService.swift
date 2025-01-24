import Foundation

@globalActor actor PersistenceService {
    static let shared = PersistenceService()
    
    private let userDefaults: UserDefaults
    private let saveKey = "cycleDays"
    
    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func loadCycleDays() throws -> [CycleDay] {
        guard let data = userDefaults.data(forKey: saveKey) else {
            return []
        }
        return try JSONDecoder().decode([CycleDay].self, from: data)
    }
    
    func saveCycleDays(_ days: [CycleDay]) throws {
        let data = try JSONEncoder().encode(days)
        userDefaults.set(data, forKey: saveKey)
    }
} 