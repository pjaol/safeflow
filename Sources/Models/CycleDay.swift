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

    var sfSymbol: String {
        switch self {
        case .spotting: return "drop"
        case .light: return "drop.halffull"
        case .medium: return "drop.fill"
        case .heavy: return "drop.triangle.fill"
        }
    }
}

// MARK: - Symptom Category

enum SymptomCategory: String, CaseIterable {
    case pain
    case energy
    case digestive

    var localizedName: String {
        switch self {
        case .pain: return NSLocalizedString("Pain", comment: "")
        case .energy: return NSLocalizedString("Energy", comment: "")
        case .digestive: return NSLocalizedString("Digestive", comment: "")
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
        case .breastTenderness: return NSLocalizedString("Tenderness", comment: "")
        case .backPain: return NSLocalizedString("Back Pain", comment: "")
        case .acne: return NSLocalizedString("Acne", comment: "")
        case .fatigue: return NSLocalizedString("Fatigue", comment: "")
        case .insomnia: return NSLocalizedString("Insomnia", comment: "")
        case .highEnergy: return NSLocalizedString("High Energy", comment: "")
        case .brainFog: return NSLocalizedString("Brain Fog", comment: "")
        case .foodCravings: return NSLocalizedString("Cravings", comment: "")
        case .nausea: return NSLocalizedString("Nausea", comment: "")
        case .appetiteChanges: return NSLocalizedString("Appetite", comment: "")
        case .dischargeChanges: return NSLocalizedString("Discharge", comment: "")
        case .mittelschmerz: return NSLocalizedString("Ovulation", comment: "")
        }
    }

    var sfSymbol: String {
        switch self {
        case .cramps: return "bolt.fill"
        case .headache: return "waveform.path.ecg"
        case .bloating: return "circle.dashed"
        case .breastTenderness: return "heart.fill"
        case .backPain: return "figure.walk"
        case .acne: return "allergens"
        case .fatigue: return "battery.25percent"
        case .insomnia: return "moon.stars.fill"
        case .highEnergy: return "bolt.circle.fill"
        case .brainFog: return "cloud.fill"
        case .foodCravings: return "fork.knife"
        case .nausea: return "drop.triangle.fill"
        case .appetiteChanges: return "minus.circle.fill"
        case .dischargeChanges: return "drop.fill"
        case .mittelschmerz: return "mappin.circle.fill"
        }
    }

    var category: SymptomCategory {
        switch self {
        case .cramps, .headache, .bloating, .breastTenderness, .backPain, .mittelschmerz:
            return .pain
        case .fatigue, .insomnia, .highEnergy, .brainFog:
            return .energy
        case .foodCravings, .nausea, .appetiteChanges, .acne, .dischargeChanges:
            return .digestive
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

    var sfSymbol: String {
        switch self {
        case .energized: return "bolt.fill"
        case .happy: return "sun.max.fill"
        case .confident: return "star.fill"
        case .calm: return "leaf.fill"
        case .focused: return "scope"
        case .neutral: return "minus.circle.fill"
        case .foggy: return "cloud.fill"
        case .tired: return "moon.fill"
        case .sensitive: return "heart.fill"
        case .anxious: return "waveform.path.ecg"
        case .irritable: return "flame.fill"
        case .sad: return "cloud.rain.fill"
        }
    }
}
