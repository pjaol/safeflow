import Foundation

#if DEBUG || BETA
enum TestData {
    static func generateSampleData(numberOfCycles: Int = 3) -> [CycleDay] {
        var days: [CycleDay] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate past cycles
        for cycleIndex in 0..<numberOfCycles {
            // Each cycle will be approximately 28 days
            let cycleStart = calendar.date(byAdding: .day, value: -28 * (cycleIndex + 1), to: today)!
            
            // Add period days (5 days of flow)
            for dayOffset in 0..<5 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart)!
                let flow: FlowIntensity = dayOffset < 2 ? .heavy : (dayOffset < 4 ? .medium : .light)
                
                let symptoms: Set<Symptom> = dayOffset == 0 ? [.cramps, .headache] :
                                          dayOffset == 1 ? [.cramps] : []
                
                let mood: Mood = dayOffset == 0 ? .sad :
                               dayOffset == 1 ? .irritable :
                               .neutral
                
                let day = CycleDay(
                    id: UUID(),
                    date: date,
                    flow: flow,
                    symptoms: symptoms,
                    mood: mood,
                    notes: dayOffset == 0 ? "Started period" : nil
                )
                days.append(day)
            }
            
            // Add some random symptom days during the cycle
            let midCycle = calendar.date(byAdding: .day, value: 14, to: cycleStart)!
            let ovulationDay = CycleDay(
                id: UUID(),
                date: midCycle,
                flow: nil,
                symptoms: [.breastTenderness],
                mood: .happy,
                notes: "Possible ovulation"
            )
            days.append(ovulationDay)
        }
        
        return days.sorted { $0.date < $1.date }
    }
    
    @MainActor
    static func loadSampleData(into store: CycleStore) {
        let sampleData = generateSampleData()
        for day in sampleData {
            store.addOrUpdateDay(day)
        }
    }
    
    @MainActor
    static func clearAllData(from store: CycleStore) {
        store.clearAllData()
    }
}
#endif 