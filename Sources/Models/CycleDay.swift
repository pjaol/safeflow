import SwiftUI

struct CycleDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    var flow: FlowIntensity?
    var symptoms: Set<Symptom>
    var mood: Mood?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        flow: FlowIntensity? = nil,
        symptoms: Set<Symptom> = [],
        mood: Mood? = nil,
        notes: String? = nil
    ) {
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
    case vasomotor      // perimenopause + menopause
    case musculoskeletal // perimenopause + menopause
    case intimateHealth // menopause only, opt-in

    var localizedName: LocalizedStringKey {
        switch self {
        case .pain:           return "Pain"
        case .energy:         return "Energy"
        case .digestive:      return "Body"
        case .vasomotor:      return "Hot Flashes"
        case .musculoskeletal: return "Joints"
        case .intimateHealth: return "Intimate Health"
        }
    }

    var localizedNameString: String {
        switch self {
        case .pain:           return String(localized: "Pain")
        case .energy:         return String(localized: "Energy")
        case .digestive:      return String(localized: "Body")
        case .vasomotor:      return String(localized: "Hot Flashes")
        case .musculoskeletal: return String(localized: "Joints")
        case .intimateHealth: return String(localized: "Intimate Health")
        }
    }

    /// Life stages for which this category is visible.
    /// `.regular` and `.irregular` always see pain/energy/digestive only.
    var visibleForStages: Set<LifeStage> {
        switch self {
        case .pain, .energy, .digestive:
            return Set(LifeStage.allCases)
        case .vasomotor, .musculoskeletal:
            return [.perimenopause, .menopause]
        case .intimateHealth:
            return [.menopause]
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

    // Vasomotor (perimenopause + menopause)
    case hotFlashes
    case nightSweats
    case chills

    // Musculoskeletal (perimenopause + menopause)
    case jointPain
    case muscleAches
    case exerciseRecovery

    // Intimate health (menopause, opt-in)
    case vaginalDryness
    case urinaryUrgency
    case painWithSex

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
        case .hotFlashes: return "Hot Flashes"
        case .nightSweats: return "Night Sweats"
        case .chills: return "Chills"
        case .jointPain: return "Joint Pain"
        case .muscleAches: return "Muscle Aches"
        case .exerciseRecovery: return "Exercise Recovery"
        case .vaginalDryness: return "Vaginal Dryness"
        case .urinaryUrgency: return "Urinary Urgency"
        case .painWithSex: return "Pain With Sex"
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
        case .hotFlashes: return String(localized: "Hot Flashes")
        case .nightSweats: return String(localized: "Night Sweats")
        case .chills: return String(localized: "Chills")
        case .jointPain: return String(localized: "Joint Pain")
        case .muscleAches: return String(localized: "Muscle Aches")
        case .exerciseRecovery: return String(localized: "Exercise Recovery")
        case .vaginalDryness: return String(localized: "Vaginal Dryness")
        case .urinaryUrgency: return String(localized: "Urinary Urgency")
        case .painWithSex: return String(localized: "Pain With Sex")
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
        case .hotFlashes: return "thermometer.sun.fill"
        case .nightSweats: return "moon.fill"
        case .chills: return "snowflake"
        case .jointPain: return "figure.strengthtraining.traditional"
        case .muscleAches: return "figure.flexibility"
        case .exerciseRecovery: return "arrow.clockwise.heart"
        case .vaginalDryness: return "drop.halffull"
        case .urinaryUrgency: return "exclamationmark.circle.fill"
        case .painWithSex: return "heart.slash.fill"
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
        case .hotFlashes, .nightSweats, .chills:
            return .vasomotor
        case .jointPain, .muscleAches, .exerciseRecovery:
            return .musculoskeletal
        case .vaginalDryness, .urinaryUrgency, .painWithSex:
            return .intimateHealth
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
