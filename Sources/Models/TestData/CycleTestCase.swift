import Foundation

struct CycleTestCase: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let entries: [CycleDayTestEntry]
    let expectedPredictions: [Date]
    let metadata: [String: String]
    
    init(name: String, description: String, entries: [CycleDayTestEntry], expectedPredictions: [Date], metadata: [String: String] = [:]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.entries = entries
        self.expectedPredictions = expectedPredictions
        self.metadata = metadata
    }
}

struct CycleDayTestEntry {
    let date: Date
    let flow: FlowIntensity?
    let symptoms: Set<Symptom>
    let mood: Mood?
    let sleepQuality: WellbeingLevel?
    let energyLevel: WellbeingLevel?
    let stressLevel: WellbeingLevel?
    let notes: String?

    init(
        date: Date,
        flow: FlowIntensity? = nil,
        symptoms: Set<Symptom> = [],
        mood: Mood? = nil,
        sleepQuality: WellbeingLevel? = nil,
        energyLevel: WellbeingLevel? = nil,
        stressLevel: WellbeingLevel? = nil,
        notes: String? = nil
    ) {
        self.date = date
        self.flow = flow
        self.symptoms = symptoms
        self.mood = mood
        self.sleepQuality = sleepQuality
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.notes = notes
    }
}

/// CSV format:
/// date,flow,symptoms,mood,sleep,energy,stress,notes
/// 2024-01-01,light,"cramps,headache",happy,high,medium,low,"First day of period"
/// 2024-01-02,medium,,neutral,,,,
/// 
/// Expected predictions (separate file with same base name + "_predictions.csv"):
/// date
/// 2024-01-29
/// 2024-02-26 