import SwiftUI
import Combine

// MARK: - DartboardCategory

enum DartboardCategory: Int, CaseIterable {
    case pain
    case energy
    case mood
    case gut

    var label: String {
        switch self {
        case .pain:   return "Pain"
        case .energy: return "Energy"
        case .mood:   return "Mood"
        case .gut:    return "Body"
        }
    }

    var sfSymbol: String {
        switch self {
        case .pain:   return "exclamationmark.triangle.fill"
        case .energy: return "bolt.fill"
        case .mood:   return "face.smiling"
        case .gut:    return "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .pain:   return AppTheme.Colors.dartPain
        case .energy: return AppTheme.Colors.dartEnergy
        case .mood:   return AppTheme.Colors.dartMood
        case .gut:    return AppTheme.Colors.dartGut
        }
    }


    var isSingleSelect: Bool { self == .mood }

    var items: [DartboardItem] {
        switch self {
        case .pain:
            return [
                DartboardItem(symptom: .cramps,          sfSymbol: "waveform.path.ecg"),
                DartboardItem(symptom: .headache,        sfSymbol: "brain.head.profile"),
                DartboardItem(symptom: .bloating,        sfSymbol: "humidity.fill"),
                DartboardItem(symptom: .breastTenderness,sfSymbol: "heart.fill"),
                DartboardItem(symptom: .backPain,        sfSymbol: "figure.walk"),
                DartboardItem(symptom: .mittelschmerz,   sfSymbol: "location.fill"),
            ]
        case .energy:
            return [
                DartboardItem(symptom: .fatigue,    sfSymbol: "moon.zzz"),
                DartboardItem(symptom: .insomnia,   sfSymbol: "moon.stars.fill"),
                DartboardItem(symptom: .highEnergy, sfSymbol: "sun.max.fill"),
                DartboardItem(symptom: .brainFog,   sfSymbol: "cloud.fog"),
            ]
        case .mood:
            // Curated 6: most distinct emotional states
            return [
                DartboardItem(mood: .energized, sfSymbol: "bolt.circle.fill"),
                DartboardItem(mood: .happy,     sfSymbol: "face.smiling.fill"),
                DartboardItem(mood: .calm,      sfSymbol: "leaf.fill"),
                DartboardItem(mood: .neutral,   sfSymbol: "circle.fill"),
                DartboardItem(mood: .anxious,   sfSymbol: "antenna.radiowaves.left.and.right"),
                DartboardItem(mood: .sad,       sfSymbol: "eye.slash.fill"),
            ]
        case .gut:
            return [
                DartboardItem(symptom: .foodCravings,     sfSymbol: "fork.knife"),
                DartboardItem(symptom: .nausea,           sfSymbol: "drop.triangle.fill"),
                DartboardItem(symptom: .appetiteChanges,  sfSymbol: "minus.circle.fill"),
                DartboardItem(symptom: .dischargeChanges, sfSymbol: "drop.fill"),
                DartboardItem(symptom: .acne,             sfSymbol: "allergens"),
            ]
        }
    }
}

// MARK: - DartboardItem

struct DartboardItem: Identifiable, Equatable {
    let id: String
    let label: String
    let sfSymbol: String
    let backingSymptom: Symptom?
    let backingMood: Mood?

    init(symptom: Symptom, sfSymbol: String) {
        self.id = symptom.rawValue
        self.label = symptom.localizedName
        self.sfSymbol = sfSymbol
        self.backingSymptom = symptom
        self.backingMood = nil
    }

    init(mood: Mood, sfSymbol: String) {
        self.id = mood.rawValue
        self.label = mood.localizedName
        self.sfSymbol = sfSymbol
        self.backingSymptom = nil
        self.backingMood = mood
    }
}

// MARK: - DartboardViewModel

@MainActor
final class DartboardViewModel: ObservableObject {

    // MARK: Persisted state (mirrors today's CycleDay)
    @Published private(set) var committedSymptoms: Set<Symptom> = []
    @Published private(set) var committedMood: Mood? = nil
    @Published private(set) var committedFlow: FlowIntensity? = nil
    @Published private(set) var committedNotes: String = ""

    // MARK: UI state
    @Published var selectedCategory: DartboardCategory = .pain
    @Published var stripDragOffset: CGFloat = 0

    // MARK: Geometry (set once from GeometryReader)
    var boardSize: CGSize = .zero
    let innerRadiusFraction: CGFloat = 0.21
    let outerRadiusFraction: CGFloat = 0.74
    let segmentGapDegrees: Double = 3.0

    // MARK: Haptics
    private let rigidImpact  = UIImpactFeedbackGenerator(style: .rigid)
    private let successNote  = UINotificationFeedbackGenerator()

    // MARK: Dependencies
    private let cycleStore: CycleStore

    init(cycleStore: CycleStore) {
        self.cycleStore = cycleStore
        rigidImpact.prepare()
        successNote.prepare()
    }

    // MARK: - Load existing day

    func loadFromStore() {
        if let day = cycleStore.getCurrentDay() {
            committedSymptoms = day.symptoms
            committedMood     = day.mood
            committedFlow     = day.flow
            committedNotes    = day.notes ?? ""
        }
    }

    func commitNotes(_ text: String) {
        committedNotes = text
        let today    = Calendar.current.startOfDay(for: Date())
        let existing = cycleStore.getCurrentDay()
        let day = CycleDay(
            id:       existing?.id ?? UUID(),
            date:     existing?.date ?? today,
            flow:     existing?.flow ?? committedFlow,
            symptoms: existing?.symptoms ?? committedSymptoms,
            mood:     existing?.mood ?? committedMood,
            notes:    text.isEmpty ? nil : text
        )
        cycleStore.addOrUpdateDay(day)
    }

    // MARK: - Derived state

    var currentItems: [DartboardItem] { selectedCategory.items }

    func isItemActive(_ item: DartboardItem) -> Bool {
        if let symptom = item.backingSymptom {
            return committedSymptoms.contains(symptom)
        }
        if let mood = item.backingMood {
            return committedMood == mood
        }
        return false
    }

    // MARK: - Segment geometry

    /// Angular width of each segment in the current category, accounting for gaps.
    var segmentAngleDegrees: Double {
        let n = Double(currentItems.count)
        return (360.0 - n * segmentGapDegrees) / n
    }

    /// Start angle (degrees, clockwise from top) for segment at index.
    func startAngle(for index: Int) -> Double {
        let n = Double(currentItems.count)
        let slotWidth = 360.0 / n
        return -90.0 + Double(index) * slotWidth + segmentGapDegrees / 2.0
    }

    func endAngle(for index: Int) -> Double {
        startAngle(for: index) + segmentAngleDegrees
    }

    /// Midpoint angle for label/icon placement.
    func midAngle(for index: Int) -> Double {
        startAngle(for: index) + segmentAngleDegrees / 2.0
    }


    // MARK: - Selection logic

    func toggleItem(_ item: DartboardItem) {
        if selectedCategory.isSingleSelect {
            committedMood = (committedMood == item.backingMood) ? nil : item.backingMood
        } else if let symptom = item.backingSymptom {
            if committedSymptoms.contains(symptom) {
                committedSymptoms.remove(symptom)
            } else {
                committedSymptoms.insert(symptom)
            }
        }
    }

    func commitSelection() {
        let today = Calendar.current.startOfDay(for: Date())
        let existing = cycleStore.getCurrentDay()
        // Preserve data from all other categories; only replace current category's data
        var mergedSymptoms = existing?.symptoms ?? []
        if !selectedCategory.isSingleSelect {
            let categorySymptoms: Set<Symptom>
            switch selectedCategory {
            case .pain:
                categorySymptoms = Set(Symptom.allCases.filter { $0.category == .pain })
            case .energy:
                categorySymptoms = Set(Symptom.allCases.filter { $0.category == .energy })
            case .gut:
                categorySymptoms = Set(Symptom.allCases.filter { $0.category == .digestive })
            case .mood:
                categorySymptoms = []
            }
            mergedSymptoms.subtract(categorySymptoms)
            mergedSymptoms.formUnion(committedSymptoms.filter { categorySymptoms.contains($0) })
        }

        let day = CycleDay(
            id:       existing?.id ?? UUID(),
            date:     existing?.date ?? today,
            flow:     committedFlow ?? existing?.flow,
            symptoms: mergedSymptoms,
            mood:     selectedCategory.isSingleSelect ? committedMood : existing?.mood,
            notes:    existing?.notes
        )
        cycleStore.addOrUpdateDay(day)
        successNote.notificationOccurred(.success)
    }

    // MARK: - Flow

    func commitFlow(_ intensity: FlowIntensity?) {
        committedFlow = intensity
        let today = Calendar.current.startOfDay(for: Date())
        let existing = cycleStore.getCurrentDay()
        let day = CycleDay(
            id:       existing?.id ?? UUID(),
            date:     existing?.date ?? today,
            flow:     intensity,
            symptoms: existing?.symptoms ?? committedSymptoms,
            mood:     existing?.mood ?? committedMood,
            notes:    existing?.notes
        )
        cycleStore.addOrUpdateDay(day)
    }

    // MARK: - Category strip

    func categoryStripSnapped(to category: DartboardCategory) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        // Sync committed state from the new category's perspective
        loadFromStore()
        // Nothing to reset — tap model has no transient marker state
        rigidImpact.impactOccurred()
    }
}
