import Foundation

// MARK: - Tip

/// A phase tip shown on PhaseTipCard. Loaded from Resources/Content/tips.json.
struct ContentTip: Codable, Identifiable {
    let id: String
    let phase: String?          // menstrual | follicular | ovulatory | luteal | any; nil for life-stage tips
    let lifeStage: String?      // regular | irregular | perimenopause | menopause | paused; nil for phase tips
    let title: String
    let body: String
    let sfSymbol: String
    let priority: String        // high | medium | low
    let cycleCountMin: Int?
    let symptomsAny: [String]   // show if user logged any of these
    let symptomsAll: [String]   // show only if user logged all of these
    let mood: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id, phase, title, body
        case lifeStage      = "life_stage"
        case sfSymbol       = "sf_symbol"
        case priority
        case cycleCountMin  = "cycle_count_min"
        case symptomsAny    = "symptoms_any"
        case symptomsAll    = "symptoms_all"
        case mood, source
    }
}

// MARK: - Nudge

/// A pattern nudge or comfort suggestion. Loaded from Resources/Content/nudges.json.
struct ContentNudge: Codable, Identifiable {
    let id: String
    let type: String            // health | comfort
    let title: String
    let body: String
    let sfSymbol: String
    let priority: String
    let cycleCountMin: Int?
    let avgCycleMax: Int?       // trigger if avg cycle < this
    let avgCycleMin: Int?       // trigger if avg cycle > this
    let variabilityMin: Double? // trigger if variability > this
    let periodLengthMin: Int?   // trigger if period length > this
    let symptomsAny: [String]
    let symptomsAll: [String]
    let dismissible: Bool
    let checkType: String?      // optional named check, e.g. "cycle_overdue"

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case sfSymbol        = "sf_symbol"
        case priority
        case cycleCountMin   = "cycle_count_min"
        case avgCycleMax     = "avg_cycle_max"
        case avgCycleMin     = "avg_cycle_min"
        case variabilityMin  = "variability_min"
        case periodLengthMin = "period_length_min"
        case symptomsAny     = "symptoms_any"
        case symptomsAll     = "symptoms_all"
        case dismissible
        case checkType       = "check_type"
    }
}

// MARK: - Signal

/// A severity signal (escalating pattern alert). Loaded from Resources/Content/signals.json.
struct ContentSignal: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let sfSymbol: String
    let priority: String
    let cycleCountMin: Int?
    let checkType: String       // maps to a named check in ContentEvaluator
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case sfSymbol      = "sf_symbol"
        case priority
        case cycleCountMin = "cycle_count_min"
        case checkType     = "check_type"
        case source
    }
}

// MARK: - Population Norm (for InsightCard)

/// Population-level prevalence data for a symptom × phase combination.
/// Loaded from Resources/Content/insights.json.
struct ContentInsight: Codable, Identifiable {
    let id: String
    let symptom: String         // Symptom rawValue, or "mood" for mood norms
    let phase: String           // menstrual | follicular | ovulatory | luteal
    let prevalence: String      // very_common | common | fairly_common | less_common | rare
    let percentageString: String // e.g. "around 70%"
    let note: String?           // optional clinical context
    // Mood-specific fields (only set when symptom == "mood")
    let valence: String?        // positive | negative | neutral

    enum CodingKeys: String, CodingKey {
        case id, symptom, phase, prevalence
        case percentageString = "percentage_string"
        case note, valence
    }
}

// MARK: - Resource

/// A bundled support resource (org, helpline, condition guide).
/// Loaded from Resources/Content/resources.json.
struct ContentResource: Codable, Identifiable {
    let id: String
    let category: String        // ob_gyn | pmdd | endometriosis | pcos | gp | crisis | mental_health
    let name: String
    let shortDescription: String
    let url: String?
    let phone: String?
    let region: String          // US | UK | AU | global
    let languages: [String]
    let tags: [String]          // used for contextual surfacing

    enum CodingKeys: String, CodingKey {
        case id, category, name
        case shortDescription = "short_description"
        case url, phone, region, languages, tags
    }
}
