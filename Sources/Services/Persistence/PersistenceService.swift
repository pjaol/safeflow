import Foundation

@globalActor actor PersistenceService {
    static let shared = PersistenceService()

    private let userDefaults: UserDefaults
    private let cycleDaysKey = "cycleDays"
    private let seedDataKey = "cycleSeedData"

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadCycleDays() throws -> [CycleDay] {
        guard let data = userDefaults.data(forKey: cycleDaysKey) else { return [] }
        return try JSONDecoder().decode([CycleDay].self, from: data)
    }

    func saveCycleDays(_ days: [CycleDay]) throws {
        let data = try JSONEncoder().encode(days)
        userDefaults.set(data, forKey: cycleDaysKey)
    }

    func loadSeedData() throws -> CycleSeedData? {
        guard let data = userDefaults.data(forKey: seedDataKey) else { return nil }
        return try JSONDecoder().decode(CycleSeedData.self, from: data)
    }

    func saveSeedData(_ seed: CycleSeedData) throws {
        let data = try JSONEncoder().encode(seed)
        userDefaults.set(data, forKey: seedDataKey)
    }
}
