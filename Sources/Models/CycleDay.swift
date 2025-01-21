import Foundation

struct CycleDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    var flow: FlowIntensity?
    var symptoms: Set<Symptom>
    var mood: Mood?
    var notes: String?
    
    init(id: UUID = UUID(), date: Date, flow: FlowIntensity? = nil, symptoms: Set<Symptom> = [], mood: Mood? = nil, notes: String? = nil) {
        self.id = id
        self.date = date
        self.flow = flow
        self.symptoms = symptoms
        self.mood = mood
        self.notes = notes
    }
}

enum FlowIntensity: String, Codable, CaseIterable {
    case light
    case medium
    case heavy
    case spotting
}

enum Symptom: String, Codable, CaseIterable {
    case cramps
    case headache
    case fatigue
    case bloating
    case breastTenderness
    
    var localizedName: String {
        switch self {
        case .cramps: return NSLocalizedString("Cramps", comment: "")
        case .headache: return NSLocalizedString("Headache", comment: "")
        case .fatigue: return NSLocalizedString("Fatigue", comment: "")
        case .bloating: return NSLocalizedString("Bloating", comment: "")
        case .breastTenderness: return NSLocalizedString("Breast Tenderness", comment: "")
        }
    }
}

enum Mood: String, Codable, CaseIterable {
    case happy
    case neutral
    case sad
    case anxious
    case irritable
    
    var localizedName: String {
        switch self {
        case .happy: return NSLocalizedString("Happy", comment: "")
        case .neutral: return NSLocalizedString("Neutral", comment: "")
        case .sad: return NSLocalizedString("Sad", comment: "")
        case .anxious: return NSLocalizedString("Anxious", comment: "")
        case .irritable: return NSLocalizedString("Irritable", comment: "")
        }
    }
} 