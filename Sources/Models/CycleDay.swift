import SwiftUI

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

    var localizedName: LocalizedStringKey {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }

    var localizedNameString: String {
        switch self {
        case .spotting: return String(localized: "Spotting")
        case .light: return String(localized: "Light")
        case .medium: return String(localized: "Medium")
        case .heavy: return String(localized: "Heavy")
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

    var localizedName: LocalizedStringKey {
        switch self {
        case .pain: return "Pain"
        case .energy: return "Energy"
        case .digestive: return "Body"
        }
    }

    var localizedNameString: String {
        switch self {
        case .pain: return String(localized: "Pain")
        case .energy: return String(localized: "Energy")
        case .digestive: return String(localized: "Body")
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

    var localizedName: LocalizedStringKey {
        switch self {
        case .cramps: return "Cramps"
        case .headache: return "Headache"
        case .bloating: return "Bloating"
        case .breastTenderness: return "Tenderness"
        case .backPain: return "Back Pain"
        case .acne: return "Acne"
        case .fatigue: return "Fatigue"
        case .insomnia: return "Insomnia"
        case .highEnergy: return "High Energy"
        case .brainFog: return "Brain Fog"
        case .foodCravings: return "Cravings"
        case .nausea: return "Nausea"
        case .appetiteChanges: return "Appetite"
        case .dischargeChanges: return "Discharge"
        case .mittelschmerz: return "Ovulation"
        }
    }

    var localizedNameString: String {
        switch self {
        case .cramps: return String(localized: "Cramps")
        case .headache: return String(localized: "Headache")
        case .bloating: return String(localized: "Bloating")
        case .breastTenderness: return String(localized: "Tenderness")
        case .backPain: return String(localized: "Back Pain")
        case .acne: return String(localized: "Acne")
        case .fatigue: return String(localized: "Fatigue")
        case .insomnia: return String(localized: "Insomnia")
        case .highEnergy: return String(localized: "High Energy")
        case .brainFog: return String(localized: "Brain Fog")
        case .foodCravings: return String(localized: "Cravings")
        case .nausea: return String(localized: "Nausea")
        case .appetiteChanges: return String(localized: "Appetite")
        case .dischargeChanges: return String(localized: "Discharge")
        case .mittelschmerz: return String(localized: "Ovulation")
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

    var localizedName: LocalizedStringKey {
        switch self {
        case .energized: return "Energized"
        case .happy: return "Happy"
        case .confident: return "Confident"
        case .calm: return "Calm"
        case .focused: return "Focused"
        case .neutral: return "Neutral"
        case .foggy: return "Foggy"
        case .tired: return "Tired"
        case .sensitive: return "Sensitive"
        case .anxious: return "Anxious"
        case .irritable: return "Irritable"
        case .sad: return "Sad"
        }
    }

    var localizedNameString: String {
        switch self {
        case .energized: return String(localized: "Energized")
        case .happy: return String(localized: "Happy")
        case .confident: return String(localized: "Confident")
        case .calm: return String(localized: "Calm")
        case .focused: return String(localized: "Focused")
        case .neutral: return String(localized: "Neutral")
        case .foggy: return String(localized: "Foggy")
        case .tired: return String(localized: "Tired")
        case .sensitive: return String(localized: "Sensitive")
        case .anxious: return String(localized: "Anxious")
        case .irritable: return String(localized: "Irritable")
        case .sad: return String(localized: "Sad")
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
