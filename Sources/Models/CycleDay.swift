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
    case spotting
    case light
    case medium
    case heavy

    var localizedName: String {
        switch self {
        case .spotting: return NSLocalizedString("Spotting", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .medium: return NSLocalizedString("Medium", comment: "")
        case .heavy: return NSLocalizedString("Heavy", comment: "")
        }
    }

    var emoji: String {
        switch self {
        case .spotting: return "🩸"
        case .light: return "💧"
        case .medium: return "🌊"
        case .heavy: return "🫧"
        }
    }
}

// MARK: - Symptom Category

enum SymptomCategory: String, CaseIterable {
    case pain
    case energy
    case digestive
    case hormonal

    var localizedName: String {
        switch self {
        case .pain: return NSLocalizedString("Pain", comment: "")
        case .energy: return NSLocalizedString("Energy", comment: "")
        case .digestive: return NSLocalizedString("Digestive", comment: "")
        case .hormonal: return NSLocalizedString("Hormonal", comment: "")
        }
    }
}

// MARK: - Symptom

enum Symptom: String, Codable, CaseIterable {
    // Pain & Physical (existing)
    case cramps
    case headache
    case bloating
    case breastTenderness
    // Pain & Physical (new)
    case backPain
    case acne

    // Energy (existing)
    case fatigue
    // Energy (new)
    case insomnia
    case highEnergy
    case brainFog

    // Digestive (new)
    case foodCravings
    case nausea
    case appetiteChanges

    // Hormonal indicators (new)
    case dischargeChanges
    case mittelschmerz

    var localizedName: String {
        switch self {
        case .cramps: return NSLocalizedString("Cramps", comment: "")
        case .headache: return NSLocalizedString("Headache", comment: "")
        case .bloating: return NSLocalizedString("Bloating", comment: "")
        case .breastTenderness: return NSLocalizedString("Breast Tenderness", comment: "")
        case .backPain: return NSLocalizedString("Back Pain", comment: "")
        case .acne: return NSLocalizedString("Acne", comment: "")
        case .fatigue: return NSLocalizedString("Fatigue", comment: "")
        case .insomnia: return NSLocalizedString("Insomnia", comment: "")
        case .highEnergy: return NSLocalizedString("High Energy", comment: "")
        case .brainFog: return NSLocalizedString("Brain Fog", comment: "")
        case .foodCravings: return NSLocalizedString("Food Cravings", comment: "")
        case .nausea: return NSLocalizedString("Nausea", comment: "")
        case .appetiteChanges: return NSLocalizedString("Appetite Changes", comment: "")
        case .dischargeChanges: return NSLocalizedString("Discharge Changes", comment: "")
        case .mittelschmerz: return NSLocalizedString("Mid-Cycle Cramp", comment: "")
        }
    }

    var emoji: String {
        switch self {
        case .cramps: return "😣"
        case .headache: return "🤕"
        case .bloating: return "🫄"
        case .breastTenderness: return "💛"
        case .backPain: return "🔙"
        case .acne: return "😶"
        case .fatigue: return "😴"
        case .insomnia: return "🌙"
        case .highEnergy: return "⚡️"
        case .brainFog: return "🌫️"
        case .foodCravings: return "🍫"
        case .nausea: return "🤢"
        case .appetiteChanges: return "🍽️"
        case .dischargeChanges: return "💧"
        case .mittelschmerz: return "📍"
        }
    }

    var category: SymptomCategory {
        switch self {
        case .cramps, .headache, .bloating, .breastTenderness, .backPain, .acne:
            return .pain
        case .fatigue, .insomnia, .highEnergy, .brainFog:
            return .energy
        case .foodCravings, .nausea, .appetiteChanges:
            return .digestive
        case .dischargeChanges, .mittelschmerz:
            return .hormonal
        }
    }
}

// MARK: - Mood

enum Mood: String, Codable, CaseIterable {
    // Positive
    case energized
    case happy
    case confident
    case calm
    case focused
    // Neutral
    case neutral
    // Negative
    case foggy
    case tired
    case sensitive
    case anxious
    case irritable
    case sad

    var localizedName: String {
        switch self {
        case .energized: return NSLocalizedString("Energized", comment: "")
        case .happy: return NSLocalizedString("Happy", comment: "")
        case .confident: return NSLocalizedString("Confident", comment: "")
        case .calm: return NSLocalizedString("Calm", comment: "")
        case .focused: return NSLocalizedString("Focused", comment: "")
        case .neutral: return NSLocalizedString("Neutral", comment: "")
        case .foggy: return NSLocalizedString("Foggy", comment: "")
        case .tired: return NSLocalizedString("Tired", comment: "")
        case .sensitive: return NSLocalizedString("Sensitive", comment: "")
        case .anxious: return NSLocalizedString("Anxious", comment: "")
        case .irritable: return NSLocalizedString("Irritable", comment: "")
        case .sad: return NSLocalizedString("Sad", comment: "")
        }
    }

    var emoji: String {
        switch self {
        case .energized: return "⚡️"
        case .happy: return "😊"
        case .confident: return "💪"
        case .calm: return "😌"
        case .focused: return "🎯"
        case .neutral: return "😐"
        case .foggy: return "🌫️"
        case .tired: return "😴"
        case .sensitive: return "🥺"
        case .anxious: return "😰"
        case .irritable: return "😤"
        case .sad: return "😢"
        }
    }
}
